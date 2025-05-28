(
  '(82 117 110 110 105 110 103 32 117 110 105 116 32 34) sputc
  sputc
  34 putc
  10 putc
) $test-unit

(%v
  if (^v not) (
    '(102 97 105 108 10) sputc
  ) endif
) $test-assert

(%e %v
  if (^v ^e neq) (
    '(102 97 105 108 44 32 101 120 112 101 99 116 101 100 58 10) sputc
    ^e print
    '(103 111 116 58 10) sputc
    ^v print
  ) endif
) $test-asserteq

'(48 49 50 51 52 53 54 55 56 57 97 98 99 100 101 102) l>b $test-hex-nibble

(%buf
  ^buf bs %l

  if (^l) (
    0 %i
    (
      ^i ^buf @ dup
      4 >> ^test-hex-nibble @ putc
      15 binary-and ^test-hex-nibble @ putc
      ^i 1 + $i
      ^i ^l neq
    ) rep
  ) else (
    '(40 110 117 108 108 41) sputc
  ) endif
) $test-putbuf

(%e %v
  ^e list-len ^v bs eq %f

  if (^f) (
    ; they're equally long

    0 %i
    ^e (
      dup car ^i ^v @ eq ^f and $f
      ^i 1 + $i
      cdr dup
    ) rep drop
  ) endif

  if (^f not) (
    '(102 97 105 108 44 32 101 120 112 101 99 116 101 100 58 10) sputc
    ^e l>b test-putbuf 10 putc
    '(103 111 116 58 10) sputc
    ^v test-putbuf 10 putc
  ) endif
) $test-assertbeq
