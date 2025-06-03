'(48 49 50 51 52 53 54 55 56 57 97 98 99 100 101 102) l>b $print-hextable

(%base %v
  if (^v <0?) (
    45 putc
    0 ^v - $v
  ) endif

  #f %l
  if (^v 0 eq) (
    '(0) $l
  ) else (
    (
      ^l ^v ^base mod cons $l
      ^v ^base / $v

      ^v
    ) rep
  ) endif

  ^l (^print-hextable @ putc) each
) $print-num

(%self %v
  ^v type %t

  ; atom
  if (^t 0 eq) (
    ^v o>p %va

    ^va 8 + mem q@ %len
    ^va 16 + mem q@ %ptr

    (
      ^ptr mem @ putc
      ^ptr 1 + $ptr
      ^len 1 - $len
      ^len
    ) rep
  ) endif

  ; int
  if (^t 1 eq) (
    ^v 10 print-num
  ) endif

  ; prim
  if (^t 2 eq) (
    60 putc 112 putc 114 putc 105 putc 109 putc 64 putc 48 putc 120 putc
    ^v o>p 8 + mem q@ 16 print-num
    62 putc
  ) endif

  ; pair
  if (^t 3 eq) (
    40 putc
    ^v car self
    ^v cdr %o

    if (^o) (
      (
        32 putc

        if (^o type 3 eq) (
          ^o car self
          ^o cdr $o
        ) else (
          ^o self
        ) endif

        ^o
      ) rep
    ) endif

    41 putc
  ) endif

  ; env
  if (^t 4 eq) (
    60 putc 101 putc 110 putc 118 putc 32 putc
    ^v o>p 8 + mem q@ p>o self
    44 putc 32 putc 48 putc 120 putc
    ^v o>p 16 + mem q@ 16 print-num
    62 putc
  ) endif

  ; buf
  if (^t 5 eq) (
    34 putc

    0 %ptr
    ^v bs %len

    if (^len) (
      (
        ^ptr ^v @ dup
        4 >> print-hextable @ putc
        15 binary-and print-hextable @ putc

        ^ptr 1 + $ptr
        ^len 1 - $len
        ^len
      ) rep
    ) endif

    34 putc
  ) endif

  ; else
  if (^t 5 >) (
    60 putc 63 putc
    ^v o>p mem @ 10 print-num
    44 putc 32 putc 48 putc 120 putc
    ^v o>p 16 print-num
    62 putc
  ) endif
) rec %print-internal

(print-internal 10 putc) $print
