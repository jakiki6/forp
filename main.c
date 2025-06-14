#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

uint8_t boot_blob[] = {
#include "boot.h"
};

#ifndef DEBUG
    #define DEBUG 0
#endif

#define ARENA_SIZE (1 << 24)
#define ARENA_THRESHOLD 1
#define GC_LIFETIME 1000000

#define UNUSED(x) (void) x
#define error(msg)                                                                                                             \
    do {                                                                                                                       \
        fprintf(stderr, "FATAL ERROR: %s\n", msg);                                                                             \
        abort();                                                                                                               \
    } while (0);

#define TYPE_ATOM 0
#define TYPE_INT 1
#define TYPE_PRIM 2
#define TYPE_PAIR 3
#define TYPE_ENV 4
#define TYPE_BUF 5
#define TYPE_FREE 255

#define IS_NIL(o) (o == state->nil)
#define IS_ATOM(o) ((o)->type == TYPE_ATOM)
#define IS_INT(o) ((o)->type == TYPE_INT)
#define IS_PRIM(o) ((o)->type == TYPE_PRIM)
#define IS_PAIR(o) ((o)->type == TYPE_PAIR)
#define IS_ENV(o) ((o)->type == TYPE_ENV)
#define IS_BUF(o) ((o)->type == TYPE_BUF)

#define ucar(o) (o->first)
#define ucdr(o) (o->second)

#define FLAG_REACHED 0x01
#define FLAG_NO_FREE 0x02
#define FLAG_PERSIST 0x04
#define FLAG_HIT 0x08

typedef struct obj obj_t;
typedef struct state state_t;

struct obj {
    uint8_t type;
    uint8_t flags;
    uint16_t padding1;
    uint32_t padding2;

    union {
        // atom and buf
        struct {
            size_t len;
            uint8_t *data;
        };

        // integer
        int64_t num;
        uint64_t unum;

        // primitive
        void (*func)(obj_t **env, state_t *state);

        // pair and environment
        struct {
            obj_t *first;
            obj_t *second;
        };
    };
} __attribute__((packed));

struct state {
    obj_t *stack;
    obj_t *nil;
    obj_t *t;
    obj_t *(*alloc)();
    uint64_t exit_levels;

    obj_t *atoms;
    obj_t *env_stack;
    obj_t *comp_stack;
    obj_t *quote;
    obj_t *push;
    obj_t *pop;
    obj_t *lpop;
    int gc_lifetime;
    bool gc;
};
static state_t *state;

typedef struct obj_arena obj_arena_t;
struct obj_arena {
    obj_arena_t *next;
    size_t free;
    size_t last;

    obj_t objs[];
};
static obj_arena_t *arena_head;

static obj_arena_t *arena_new() {
    obj_arena_t *arena = malloc(sizeof(obj_arena_t) + sizeof(obj_t) * ARENA_SIZE);
    arena->next = NULL;
    arena->free = ARENA_SIZE;
    arena->last = 0;

    memset(&arena->objs, 0xff, sizeof(obj_t) * ARENA_SIZE);

    return arena;
}

static obj_t *arena_alloc() {
    if (arena_head == NULL) {
        arena_head = arena_new();
    }

    obj_arena_t *head = arena_head;
    while (head) {
        if (head->free) {
            for (size_t i = 0; i < ARENA_SIZE; i++) {
                size_t index = (i + head->last) & (ARENA_SIZE - 1);

                if (head->objs[index].type == TYPE_FREE) {
                    head->free--;
                    head->objs[index].type--;
                    head->last = (index + 1) & (ARENA_SIZE - 1);
                    return &head->objs[index];
                }
            }
        }

        head = head->next;
    }

    head = arena_new();
    head->next = arena_head;
    arena_head = head;

    head->free--;
    head->objs[0].type--;
    return &head->objs[0];
}

static void arena_free(obj_t *obj) {
    obj_arena_t *head = arena_head;
    while (head) {
        if (head->free < ARENA_SIZE) {
            if (obj >= &head->objs[0] && obj <= &head->objs[ARENA_SIZE - 1]) {
                obj->type = TYPE_FREE;
                head->free++;

                break;
            }
        }

        head = head->next;
    }
}

static void arena_cleanup() {
    obj_arena_t **next = &arena_head;
    obj_arena_t *head = arena_head;
    size_t empty_count = 0;
    while (head) {
        if (head->free == ARENA_SIZE) {
            empty_count++;

            if (empty_count > ARENA_THRESHOLD) {
                *next = head->next;

                free(head);
                head = *next;

                continue;
            }
        }

        next = &head->next;
        head = head->next;
    }
}

static void gc_walk(obj_t *o) {
    if (o == NULL || o->flags & FLAG_REACHED)
        return;

    o->flags |= FLAG_REACHED;

    switch (o->type) {
        case TYPE_PAIR:
        case TYPE_ENV:
            gc_walk(o->first);
            gc_walk(o->second);
            break;
    }
}

static void gc_free(obj_t *o) {
    switch (o->type) {
        case TYPE_ATOM:
            free(o->data);
            break;

        case TYPE_BUF:
            if (!(o->flags & FLAG_NO_FREE)) {
                free(o->data);
            }
    }

    arena_free(o);
}

static void gc() {
    gc_walk(state->stack);
    gc_walk(state->atoms);
    gc_walk(state->comp_stack);

    obj_t *ehead = state->env_stack;
    while (!IS_NIL(ehead)) {
        ehead->flags |= FLAG_REACHED;
        ehead->first->flags |= FLAG_REACHED;
        gc_walk(*(obj_t **) (ehead->first->num));
        ehead = ehead->second;
    }

    obj_arena_t *head = arena_head;

    while (head) {
        if (head->free < ARENA_SIZE) {
            for (size_t i = 0; i < ARENA_SIZE; i++) {
                if (head->objs[i].type != TYPE_FREE) {
                    if (!(head->objs[i].flags & (FLAG_REACHED | FLAG_PERSIST))) {
                        bool should_break = ARENA_SIZE - head->free == 1;

                        gc_free(&head->objs[i]);

                        if (should_break) {
                            break;
                        }
                    }
                }
            }
        }

        head = head->next;
    }

    arena_cleanup();
}

static obj_t *alloc() {
    if (state->gc) {
        if (state->gc_lifetime <= 0) {
            state->gc_lifetime = GC_LIFETIME;

            gc();
        } else {
            state->gc_lifetime--;
        }
    }

    obj_t *o = arena_alloc();
    o->flags = 0;
    return o;
}

static inline obj_t *car(obj_t *o) {
    if (!IS_PAIR(o) && !IS_ENV(o))
        error("car not pair");

    return o->first;
}

static inline obj_t *cdr(obj_t *o) {
    if (!IS_PAIR(o) && !IS_ENV(o))
        error("cdr not pair");

    return o->second;
}

static obj_t *mkatom(char *name);
static obj_t *mknil() {
    if (state->nil == NULL) {
        state->nil = mkatom("#f");
    }

    return state->nil;
}

static obj_t *mkpair(obj_t *a, obj_t *b);
static obj_t *mkatom_fixed(char *name, size_t len) {
    obj_t *head = state->atoms;
    while (!IS_NIL(head)) {
        if (IS_ATOM(car(head)) && car(head)->len == len && memcmp(car(head)->data, name, len) == 0)
            return car(head);
        head = cdr(head);
    }

    obj_t *o = alloc();
    o->type = TYPE_ATOM;
    o->len = len;
    o->data = malloc(o->len);
    memcpy(o->data, name, o->len);
    state->atoms = mkpair(o, state->atoms);
    return o;
}

static obj_t *mkatom(char *name) { return mkatom_fixed(name, strlen(name)); }

static obj_t *mkint(int64_t num) {
    obj_t *o = alloc();
    o->type = TYPE_INT;
    o->num = num;
    return o;
}

static obj_t *mkprim(void (*func)(obj_t **env, state_t *state)) {
    obj_t *o = alloc();
    o->type = TYPE_PRIM;
    o->func = func;
    return o;
}

static obj_t *mkpair(obj_t *a, obj_t *b) {
    obj_t *o = alloc();
    o->type = TYPE_PAIR;
    o->first = a;
    o->second = b;
    return o;
}

static obj_t *mkenv(obj_t *body, obj_t *env) {
    obj_t *o = alloc();
    o->type = TYPE_ENV;
    o->first = body;
    o->second = env;
    return o;
}

static obj_t *mkbuf(char *buf, size_t len, bool fixed) {
    obj_t *o = alloc();
    o->type = TYPE_BUF;
    o->len = len;
    o->data = (uint8_t *) buf;
    o->flags = fixed ? FLAG_NO_FREE : 0;
    return o;
}

static inline void push(obj_t *o) { state->stack = mkpair(o, state->stack); }

static inline obj_t *pop() {
    if (IS_NIL(state->stack)) {
        error("pop from empty stack");
    }

    obj_t *tos = ucar(state->stack);
    state->stack = ucdr(state->stack);
    return tos;
}

static inline obj_t *find_env(obj_t *env, obj_t *key) {
    if (!IS_ATOM(key))
        error("env key isn't atom");

    while (!IS_NIL(env)) {
        obj_t *entry = ucar(env);
        if (key == ucar(entry))
            return ucdr(entry);
        env = ucdr(env);
    }

    fprintf(stderr, "FATAL ERROR: cannot find in env: ");
    for (size_t i = 0; i < key->len; i++) {
        fputc(key->data[i], stderr);
    }
    fputc('\n', stderr);
    abort();
}

static obj_t *put_env(obj_t *env, obj_t *key, obj_t *val) {
    obj_t *head = env;
    while (!IS_NIL(head)) {
        if (ucar(ucar(head)) == key) {
            ucar(head)->second = val;
            return env;
        }

        head = ucdr(head);
    }

    return mkpair(mkpair(key, val), env);
}

static void p_push(obj_t **env, state_t *state) {
    UNUSED(state);
    push(find_env(*env, pop()));
}

static void p_pop(obj_t **env, state_t *state) {
    UNUSED(state);
    obj_t *a = pop();
    obj_t *b = pop();
    *env = put_env(*env, a, b);
}

static void p_lpop(obj_t **env, state_t *state) {
    UNUSED(state);
    obj_t *a = pop();
    obj_t *b = pop();
    *env = mkpair(mkpair(a, b), *env);
}

static void p_cons(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();
    push(mkpair(a, b));
}

static void p_car(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    push(car(pop()));
}

static void p_cdr(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    push(cdr(pop()));
}

static void p_eq(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (a->type != b->type)
        goto f;

    switch (a->type) {
        case TYPE_INT:
            if (a->num != b->num)
                goto f;
            break;
        case TYPE_BUF:
            if (a->len != b->len)
                goto f;
            if (memcmp(a->data, b->data, a->len) != 0)
                goto f;
            break;
        default:
            if (a != b)
                goto f;
    }

    push(state->t);
    return;
f:
    push(state->nil);
    return;
}

static void p_cswap(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();

    if (!(a == state->nil || (IS_INT(a) && a->num == 0))) {
        obj_t *a, *b;
        a = pop();
        b = pop();
        push(a);
        push(b);
    }
}

static void p_type(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    push(mkint(pop()->type));
}

static void p_alloc(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();

    if (!IS_INT(a))
        goto err;
    if (a->num < 0)
        goto err;

    char *buf;
    if (a->num == 0) {
        buf = NULL;
    } else {
        buf = malloc(a->num);
        if (buf == NULL)
            goto err;

        mprotect((void *) (((uint64_t) buf) & ~0x0fff), (a->num >> 12) + 2, PROT_READ | PROT_WRITE | PROT_EXEC);
    }

    push(mkbuf(buf, a->num, false));
    return;

err:
    push(mknil());
}

static void p_buf_peek(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *b = pop();
    obj_t *a = pop();

    if (!IS_INT(a) || !IS_BUF(b))
        goto err;

    size_t index = a->num >= 0 ? (size_t) a->num : b->len + a->num;
    if (index >= b->len)
        goto err;

    push(mkint(b->data[index]));
    return;

err:
    push(mkint(0));
}

static void p_buf_poke(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *c = pop();
    obj_t *b = pop();
    obj_t *a = pop();

    if (!IS_INT(a) || !IS_INT(b) || !IS_BUF(c))
        goto err;

    size_t index = b->num >= 0 ? (size_t) b->num : c->len + b->num;
    if (index >= c->len)
        goto err;

    c->data[index] = a->num & 0xff;

err:
    return;
}

static void p_o2p(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    push(mkint((uint64_t) pop()));
}

static void p_p2o(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();

    if (!IS_INT(a))
        goto err;

    push((obj_t *) a->unum);
    return;

err:
    push(mknil());
}

static void p_buf_size(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();

    if (!IS_BUF(a))
        goto err;

    push(mkint(a->len));

err:
    return;
}

static void p_p2b(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkbuf((char *) b->num, a->num, false));
    return;

err:
    push(mknil());
}

static void p_b2p(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();

    if (!IS_BUF(a))
        goto err;

    push(mkint((int64_t) a->data));
    return;

err:
    push(mknil());
}

static void p_env(obj_t **env, state_t *state) {
    UNUSED(state);

    push(*env);
}

static void p_stack(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    push(state->stack);
}

static void p_add(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->num + a->num));
    return;

err:
    push(mknil());
}

static void p_sub(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->num - a->num));
    return;

err:
    push(mknil());
}

static void p_mul(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->num * a->num));
    return;

err:
    push(mknil());
}

static void p_div(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->num / a->num));
    return;

err:
    push(mknil());
}

static void p_mod(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(a->num < 0 ? (b->num % a->num + (b->num > 0 ? a->num : 0)) : (b->num % a->num + (b->num < 0 ? a->num : 0))));
    return;

err:
    push(mknil());
}

static void p_umul(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->unum * a->unum));
    return;

err:
    push(mknil());
}

static void p_udiv(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->unum / a->unum));
    return;

err:
    push(mknil());
}

static void p_nand(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(~(a->unum & b->unum)));
    return;

err:
    push(mknil());
}

static void p_lshift(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->unum << a->unum));
    return;

err:
    push(mknil());
}

static void p_rshift(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *a = pop();
    obj_t *b = pop();

    if (!IS_INT(a) || !IS_INT(b))
        goto err;

    push(mkint(b->unum >> a->unum));
    return;

err:
    push(mknil());
}

static void p_gc(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    state->gc_lifetime = GC_LIFETIME;
    gc();
}

static void compute(obj_t *comp, obj_t *env);
static void p_rep(obj_t **env, state_t *state) {
    UNUSED(env);
    UNUSED(state);

    obj_t *fn = pop();
    fn->flags |= FLAG_PERSIST;

    if (!IS_ENV(fn)) {
        goto exit;
    }

    while (true) {
        compute(fn->first, fn->second);

        obj_t *a = pop();
        if ((a == state->nil || (IS_INT(a) && a->num == 0))) {
            goto exit;
        }
    }

exit:
    fn->flags &= ~FLAG_PERSIST;
}

static void p_exit(obj_t **env, state_t *state) {
    UNUSED(env);

    obj_t *a = pop();

    if (IS_INT(a)) {
        state->exit_levels = a->unum;
    }
}

static char *boot = (char *) &boot_blob;
static obj_t *boot_stack;

static void skip(void) {
    while (true) {
        while (*boot == ' ' || *boot == '\t' || *boot == '\n') {
            boot++;
        }

        if (*boot == ';') {
            do {
                boot++;
            } while (*boot != '\n');
        } else {
            return;
        }
    }
}

static obj_t *read(void);
static obj_t *read_list(void) {
    if (!boot_stack) {
        skip();
        if (*boot == ')') {
            boot++;
            return state->nil;
        }
    }
    obj_t *first = read();
    obj_t *second = read_list();
    return mkpair(first, second);
}

static obj_t *read_scalar(void) {
    char *start = boot;
    size_t len = 0;
    while (!(*boot == ' ' || *boot == '\t' || *boot == '\n' || *boot == '\'' || *boot == '^' || *boot == '$' || *boot == '%' ||
             *boot == '(' || *boot == ')' || *boot == ';')) {
        boot++;
        len++;
    }

    int64_t num = 0;
    bool neg = false;
    bool found = false;
    for (size_t i = 0; i < len; i++) {
        if (i == 0 && *start == '-') {
            neg = true;
        } else if (start[i] >= '0' && start[i] <= '9') {
            num = num * 10 + (start[i] - '0');
            found = true;
        } else {
            found = false;
            break;
        }
    }

    if (found) {
        return mkint(neg ? -num : num);
    } else {
        return mkatom_fixed(start, len);
    }
}

static obj_t *read(void) {
    if (boot_stack) {
        obj_t *top = car(boot_stack);
        boot_stack = cdr(boot_stack);
        return top;
    }

    skip();

    if (*boot == '\'') {
        boot++;
        return state->quote;
    }

    if (*boot == '^') {
        boot++;
        obj_t *s = NULL;
        s = mkpair(state->push, s);
        s = mkpair(read_scalar(), s);
        s = mkpair(state->quote, s);
        boot_stack = s;
        return read();
    }

    if (*boot == '$' || *boot == '%') {
        obj_t *sym = *boot == '$' ? state->pop : state->lpop;

        boot++;
        obj_t *s = NULL;
        s = mkpair(sym, s);
        s = mkpair(read_scalar(), s);
        s = mkpair(state->quote, s);
        boot_stack = s;
        return read();
    }

    if (*boot == '(') {
        boot++;
        return read_list();
    } else {
        return read_scalar();
    }
}

static void eval(obj_t *expr, obj_t **env);
static void compute(obj_t *comp, obj_t *env) {
    state->env_stack = mkpair(mkint((int64_t) &env), state->env_stack);
    state->comp_stack = mkpair(comp, state->comp_stack);

    while (!IS_NIL(comp)) {
        if (state->exit_levels) {
            state->exit_levels--;
            break;
        }

        state->gc = true;

        obj_t *cmd = car(comp);
        comp = cdr(comp);

        if (cmd == state->quote) {
            if (IS_NIL(comp))
                error("quote needs data");
            push(car(comp));
            comp = cdr(comp);
            continue;
        }

        eval(cmd, &env);
    }

    state->env_stack = cdr(state->env_stack);
    state->comp_stack = cdr(state->comp_stack);
}
static void eval(obj_t *expr, obj_t **env) {
    state->gc = false;

    if (IS_NIL(expr) || IS_PAIR(expr)) {
        push(mkenv(expr, *env));
    } else if (IS_ATOM(expr)) {
        obj_t *val = find_env(*env, expr);

        if (IS_ENV(val)) {
            val->first->flags |= FLAG_HIT;
            compute(val->first, val->second);
        } else if (IS_PRIM(val)) {
            val->func(env, state);
        } else {
            push(val);
        }
    } else {
        push(expr);
    }
}

static obj_t *initial_env() {
    state = malloc(sizeof(state_t));
    memset(state, 0, sizeof(state_t));

    state->gc_lifetime = GC_LIFETIME;
    state->atoms = mknil();
    state->stack = mknil();
    state->env_stack = mknil();
    state->comp_stack = mknil();
    state->quote = mkatom("quote");
    state->t = mkatom("t");
    state->push = mkatom("push");
    state->pop = mkatom("pop");
    state->lpop = mkatom("lpop");

    state->alloc = &alloc;
    state->exit_levels = 0;

    obj_t *env = mknil();
    env = put_env(env, mkatom("push"), mkprim(&p_push));
    env = put_env(env, mkatom("pop"), mkprim(&p_pop));
    env = put_env(env, mkatom("lpop"), mkprim(&p_lpop));
    env = put_env(env, mkatom("cons"), mkprim(&p_cons));
    env = put_env(env, mkatom("car"), mkprim(&p_car));
    env = put_env(env, mkatom("cdr"), mkprim(&p_cdr));
    env = put_env(env, mkatom("eq"), mkprim(&p_eq));
    env = put_env(env, mkatom("cswap"), mkprim(&p_cswap));
    env = put_env(env, mkatom("type"), mkprim(&p_type));
    env = put_env(env, mkatom("alloc"), mkprim(&p_alloc));
    env = put_env(env, mkatom("@"), mkprim(&p_buf_peek));
    env = put_env(env, mkatom("!"), mkprim(&p_buf_poke));
    env = put_env(env, mkatom("o>p"), mkprim(&p_o2p));
    env = put_env(env, mkatom("p>o"), mkprim(&p_p2o));
    env = put_env(env, mkatom("bs"), mkprim(&p_buf_size));
    env = put_env(env, mkatom("p>b"), mkprim(&p_p2b));
    env = put_env(env, mkatom("b>p"), mkprim(&p_b2p));
    env = put_env(env, mkatom("env"), mkprim(&p_env));
    env = put_env(env, mkatom("stack"), mkprim(&p_stack));
    env = put_env(env, mkatom("+"), mkprim(&p_add));
    env = put_env(env, mkatom("-"), mkprim(&p_sub));
    env = put_env(env, mkatom("*"), mkprim(&p_mul));
    env = put_env(env, mkatom("/"), mkprim(&p_div));
    env = put_env(env, mkatom("mod"), mkprim(&p_mod));
    env = put_env(env, mkatom("u*"), mkprim(&p_umul));
    env = put_env(env, mkatom("u/"), mkprim(&p_udiv));
    env = put_env(env, mkatom("nand"), mkprim(&p_nand));
    env = put_env(env, mkatom("<<"), mkprim(&p_lshift));
    env = put_env(env, mkatom(">>"), mkprim(&p_rshift));
    env = put_env(env, mkatom("gc"), mkprim(&p_gc));
    env = put_env(env, mkatom("rep"), mkprim(&p_rep));
    env = put_env(env, mkatom("exit"), mkprim(&p_exit));

    env = put_env(env, mkatom("#t"), state->t);
    env = put_env(env, mkatom("#f"), state->nil);

    return env;
}

int main() {
#if DEBUG
    getc(stdin);
#endif
    obj_t *env = initial_env();
    obj_t *comp = mknil();

    comp = read();

    compute(comp, env);

    gc();
    while (arena_head) {
        obj_arena_t *next = arena_head->next;

        for (size_t i = 0; i < ARENA_SIZE; i++) {
            if (arena_head->objs[i].type == TYPE_ATOM ||
                (arena_head->objs[i].type == TYPE_BUF && !(arena_head->objs[i].flags & FLAG_NO_FREE))) {
                free(arena_head->objs[i].data);
            }
        }

        free(arena_head);
        arena_head = next;
    }

    free(state);
}
