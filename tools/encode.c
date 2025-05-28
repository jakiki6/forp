#include <stdio.h>
#include <stdbool.h>

int main(int argc, char *argv[]) {
    bool should_space = false;

    putc('\'', stdout);
    putc('(', stdout);

    char c;
    while ((c = getc(stdin)) != EOF) {
        if (should_space) {
            putc(' ', stdout);
        } else {
            should_space = true;
        }

        printf("%u", c);
    }

    putc(')', stdout);
    putc('\n', stdout);

    return 0;
}
