; stack manipulation
(%x ^x ^x) $dup
(%x %y ^y ^x ^y ^x) $2dup
(%x %y ^y ^x ^y) $over
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
(%a %b #f ^a ^b cswap drop) $and
(not swap not and not) $or
(eq not) $neq
(#f eq) $null?
(63 >>) $<0?
(<0? not) $>=0?
(- <0?) $<
(swap <) $>
(> not) $<=
(< not) $>=

; binary logic from nand
^nand $binary-nand
(nand dup nand) $binary-and
(dup nand swap dup nand nand) $binary-or
(dup nand) $binary-not
(binary-or binary-not) $binary-nor
(%a %b ^a ^b nand $c ^a ^c nand ^b ^c nand nand) $binary-xor
(binary-xor binary-not) $binary-xnor

; math? more like meth amirit
(2dup u/ u* -) $umod

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

#f %putc
(^putc each) $sputc

0 -1 p>b const $mem

(%buf %i %l
  (
    ^l car ^i ^buf !
    ^i 1 + $i
    ^l cdr dup $l
  ) rep
) $blit-list

(%l
  ^l list-len alloc %buf
  ^l 0 ^buf blit-list
  ^buf
) $l>b

(%count %dest-offset %src-offset %dest %src
  if (^count) (
    (
      ^src-offset ^src @
      ^dest-offset ^dest !

      ^src-offset 1 + $src-offset
      ^dest-offset 1 + $dest-offset
      ^count 1 - $count
      ^count
    ) rep
  ) endif
) $buf-copy

(%src
  #f %dest
  if (^src) (
    (
      ^dest ^src car cons $dest
      ^src cdr $src
      ^src
    ) rep
  ) endif
  ^dest
) $rev

(%b %a
  #f %res
  ^a type %t

  if (^t ^b type eq ^a null? not and) (
      if (^t 3 eq) (
        (
          ^res ^a car cons $res
          ^a cdr $a
          ^a
        ) rep

        (
          ^res ^b car cons $res
          ^b cdr $b
          ^b
        ) rep

        ^res rev $res
      ) endif

      if (^t 5 eq) (
        if (^a bs not) (
          ^a ^b $a $b
        ) endif

        if (^a bs) (
          ^a bs ^b bs + alloc $res

          ^a ^res 0 0 ^a bs buf-copy
          ^b ^res 0 ^a bs ^b bs buf-copy
        ) endif
      ) endif
  ) endif

  ^res
) $join

(%obuf
  ; copy to seperate
  ^obuf bs alloc %buf
  ^obuf ^buf 0 0 ^buf bs buf-copy

  ; make buffer persist
  4 ^buf o>p 1 + mem !

  ; victim object
  ^buf b>p %fn
  ^fn o>p %fptr

  ; make PRIM
  2 ^fptr mem !

  ^fn
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

(%o %v ^v o>p ^o o>p  8 + mem q!) $car!
(%o %v ^v o>p ^o o>p 16 + mem q!) $cdr!

(%n 1 alloc %buf ^n 0 ^buf  ! ^buf) $nb>b
(%n 2 alloc %buf ^n 0 ^buf w! ^buf) $nw>b
(%n 4 alloc %buf ^n 0 ^buf d! ^buf) $nd>b
(%n 8 alloc %buf ^n 0 ^buf q! ^buf) $nq>b

(%v ^v o>p 8 + mem q@ p>o) $ucar
(%v ^v o>p 16 + mem q@ p>o) $ucdr

(%wenv %wcomp
  ; victim object
  () %fn

  ^wcomp o>p ^fn o>p  8 + mem q!
  ^wenv  o>p ^fn o>p 16 + mem q!

  ^fn
) $wrap-env

(%list %key
  #f %res

  ^list (%p if (^p car ^key eq) (^p cdr car $res) endif) each

  ^res
) %assoc-ref

(%list %key
  #f %res

  ^list (%p if (^p ^key eq) (#t $res) endif) each

  ^res
) $in?
