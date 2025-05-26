'(72 101 108 108 111 32 119 111 114 108 100 33 10) sputc

(0 1 (%self %a %b %n
  if (^n 0 eq)
    ^b
  else
    (
      ^n 1 - ^a ^b + ^b self
    )
  endif
) rec force) $fibonacci

100 1 range (drop
  20 1 range
  ^fibonacci map
  drop 46 putc) each

10 putc

'(84 101 115 116 105 110 103 32 49 48 48 48 48 48 32 105 116 101 114 97 116 105 111 110 115 58 32) sputc
0 (1 + dup 100000 neq) rep
'(100 111 110 101 10) sputc

'(72 139 54 72 139 118 8 128 62 1 117 4 72 255 70 8 195) l>b native $1+
'(72 139 54 72 139 118 8 128 62 1 117 4 72 255 78 8 195) l>b native $1-

'(68 1+ print) env wrap-env force

0 alloc
  as-x64-ret
native $nop

nop
