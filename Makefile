ifdef DEBUG
CFLAGS := -Og -g -DDEBUG=1
else
CFLAGS := -O2 -g -DDEBUG=0
endif

all: main
	./main | ndisasm -b 64 -

main: main.c boot.h
	gcc $(CFLAGS) -Wall -Wextra -Werror -o $@ $<

boot.h: src/base.fp src/as/as.fp src/as/x64.fp src/main.fp
	cat $^ | sed 's/;.*//' | sed '/^$$/d' | sed ':a;N;$$!ba;s/\n/ /g' | sed ':a;s/  / /;ta' | sed ':a;s/( /(/g;ta' | sed ':a;s/ )/)/g;ta' | sed 's/^/(/' | sed 's/$$/)/' | xxd -i > $@

clean:
	rm -f main boot.h perf.data perf.data.old

valgrind: main
	valgrind ./main

perf: main
	perf record ./main
	perf report

.PHONY: all clean
