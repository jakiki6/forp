ifdef DEBUG
CFLAGS := -Og -g -DDEBUG=1
else
CFLAGS := -O2 -g -DDEBUG=0
endif

CC := clang

all: main tools/encode
	./main

main: main.c boot.h
	$(CC) $(CFLAGS) -Wall -Wextra -Werror -o $@ $<

boot.h: boot.fp
	cat $^ | xxd -i > $@

boot.fp: src/base.fp src/as/as.fp src/as/x64.fp src/arch/x64/natives.fp src/print.fp src/unit.fp src/test.fp
	cat $^ | sed 's/;.*//' | sed '/^$$/d' | sed ':a;N;$$!ba;s/\n/ /g' | sed ':a;s/  / /;ta' | sed ':a;s/( /(/g;ta' | sed ':a;s/ )/)/g;ta' | sed 's/^/(/' | sed 's/$$/)/' > $@

tools/encode: tools/encode.c
	$(CC) -O2 -o $@ $<

clean:
	rm -f main tools/encode boot.fp boot.h perf.data perf.data.old

valgrind: main
	valgrind ./main

perf: main
	perf record ./main
	perf report

size: boot.fp
	cat $^ | wc -c

.PHONY: all clean valgrund perf size
