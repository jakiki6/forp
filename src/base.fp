; stack manipulation
(%x ^x ^x) $dup
(%_) $drop
(%x %y ^x ^y) $swap
(%a %b %c ^b ^a ^c) $rot

; some basic constructs
(%x (^x)) $const
(%x x) $force

; recursion
(%f (%x (^x x) f) dup force) $Y
(%g (^g Y)) $rec

; if shenanigans
((%t %c drop c $c () ^t ^c cswap drop force) #f) $if
((%t %c drop c $c ^t () ^c cswap drop force) #t) $unless
(%t %c %u drop (%f %t force %c ^f ^t ^c cswap drop force) ^c ^t ^u cswap) $else
(%a %b %c %d ^c ^b ^a d) $endif

; equality stuff
(%c #t #f c cswap drop) $not
(eq not) $neq
(#f eq) $null?

; binary logic from nand
^nand $binary-nand
(nand dup nand) $binary-and
(dup nand swap dup nand nand) $binary-or
(dup nand) $binary-not
(binary-or binary-not) $binary-nor
(%a %b ^a ^b nand $c ^a ^c nand ^b ^c nand nand) $binary-xor
(binary-xor binary-not) $binary-xnor

; range (end start -- list)
(1 - %end 1 - %start
  #f
  (
    ^start cons
    ^start 1 - $start
    ^start ^end neq
  ) rep
) $range

; map (fn list -- out-list)
(%fn %list
  if (^list null?)
    #f
  else
    (#f %vals
      (
        ^list car fn ^vals cons $vals
        ^list cdr $list
        ^list null? not
      ) rep ^vals)
  endif
) $map

; each (fn list --)
(%fn (fn #f) map drop) $each

; list-len (list -- len)
(%list
  ^list if ^null?
    0
  else
    (0 %len
      (
        ^list cdr $list
        ^len 1 + $len
        ^list null? not
      ) rep ^len
    )
  endif
) $list-len

(^putc each) $sputc

0 -1 p>b const $mem

(%code
  if (^code list-len not)
    () const
  else
    (
      ^code list-len alloc %buf

      ; make buffer persist
      4 ^buf o>p 1 + mem !

      ; victim object
      ^buf b>p %fn
      ^fn o>p %fptr

      ; make PRIM
      2 ^fptr mem !

      0 %i
      ^code
      (^i ^buf ! ^i 1 + $i) each

      ^fn
    )
  endif
) $native

(%buf %addr %v
  ^v       255 binary-and ^addr     buf !
  ^v  8 >> 255 binary-and ^addr 1 + buf !
  ^v 16 >> 255 binary-and ^addr 2 + buf !
  ^v 24 >> 255 binary-and ^addr 3 + buf !
  ^v 32 >> 255 binary-and ^addr 4 + buf !
  ^v 40 >> 255 binary-and ^addr 5 + buf !
  ^v 48 >> 255 binary-and ^addr 6 + buf !
  ^v 56 >> 255 binary-and ^addr 7 + buf !
) $q!

(%buf %addr %v
  ^v       255 binary-and ^addr     buf !
  ^v  8 >> 255 binary-and ^addr 1 + buf !
  ^v 16 >> 255 binary-and ^addr 2 + buf !
  ^v 24 >> 255 binary-and ^addr 3 + buf !
) $d!

(%buf %addr %v
  ^v       255 binary-and ^addr     buf !
  ^v  8 >> 255 binary-and ^addr 1 + buf !
) $w!

(%buf %addr
  ^addr     ^buf @
  ^addr 1 + ^buf @  8 << binary-or
  ^addr 2 + ^buf @ 16 << binary-or
  ^addr 3 + ^buf @ 24 << binary-or
  ^addr 4 + ^buf @ 32 << binary-or
  ^addr 5 + ^buf @ 40 << binary-or
  ^addr 6 + ^buf @ 48 << binary-or
  ^addr 7 + ^buf @ 56 << binary-or
) $q@

(%buf %addr
  ^addr     ^buf @
  ^addr 1 + ^buf @  8 << binary-or
  ^addr 2 + ^buf @ 16 << binary-or
  ^addr 3 + ^buf @ 24 << binary-or
) $d@

(%buf %addr
  ^addr     ^buf @
  ^addr 1 + ^buf @  8 << binary-or
) $w@

(%wenv %wcomp
  ; victim object
  () %fn

  ^wcomp o>p ^fn o>p  8 + mem q!
  ^wenv  o>p ^fn o>p 16 + mem q!

  ^fn
) $wrap-env
