; https://wiki.osdev.org/X86-64_Instruction_Encoding#Registers
'(
  (al 0) (ax 0) (eax 0) (rax 0) (es 0) (cr0 0)
  (cl 1) (cx 1) (ecx 1) (rcx 1) (cs 1)
  (dl 2) (dx 2) (edx 2) (rdx 2) (ss 2) (cr2 2)
  (bl 3) (bx 3) (ebx 3) (rbx 3) (ds 3) (cr3 3)
  (ah 4) (spl 4) (sp 4) (esp 4) (rsp 4) (fs 4) (cr4 4) (sib 4) (none 4)
  (ch 5) (bpl 5) (bp 5) (ebp 5) (rbp 5) (gs 5) (addr 5)
  (dh 6) (sil 6) (si 6) (esi 6) (rsi 6)
  (bh 7) (dil 7) (di 7) (edi 7) (rdi 7)
  (r8b 8) (r8w 8) (r8d 8) (r8 8) (cr8 8)
  (r9b 9) (r9w 9) (r9d 9) (r9 9)
  (r10b 10) (r10w 10) (r10d 10) (r10 10)
  (r11b 11) (r11w 11) (r11d 11) (r11 11)
  (r12b 12) (r12w 12) (r12d 12) (r12 12)
  (r13b 13) (r13w 13) (r13d 13) (r13 13)
  (r14b 14) (r14w 14) (r14d 14) (r14 14)
  (r15b 15) (r15w 15) (r15d 15) (r15 15)
) $as-x64-registers

'(
  (al 0) (ax 1) (eax 2) (rax 3)
  (cl 0) (cx 1) (ecx 2) (rcx 3)
  (dl 0) (dx 1) (edx 2) (rdx 3)
  (bl 0) (bx 1) (ebx 2) (rbx 3)
  (ah 0) (spl 4) (sp 1) (esp 2) (rsp 3)
  (ch 0) (bpl 4) (bp 1) (ebp 2) (rbp 3)
  (dh 0) (sil 4) (si 1) (esi 2) (rsi 3)
  (bh 0) (dil 4) (di 1) (edi 2) (rdi 3)
  (r8b 0) (r8w 1) (r8d 2) (r8 3)
  (r9b 0) (r9w 1) (r9d 2) (r9 3)
  (r10b 0) (r10w 1) (r10d 2) (r10 3)
  (r11b 0) (r11w 1) (r11d 2) (r11 3)
  (r12b 0) (r12w 1) (r12d 2) (r12 3)
  (r13b 0) (r13w 1) (r13d 2) (r13 3)
  (r14b 0) (r14w 1) (r14d 2) (r14 3)
  (r15b 0) (r15w 1) (r15d 2) (r15 3)
) $as-x64-modes

'(
  (1 0)
  (2 1)
  (4 2)
  (8 3)
) $as-x64-radicies

195 as-1const $as-x64-ret
240 as-1const $as-x64-lock
242 as-1const dup $as-x64-repne $as-x64-repnz
243 as-1const dup dup $as-x64-rep $as-x64-repne $as-x64-repnz
46 as-1const $as-x64-cs
54 as-1const $as-x64-ss
62 as-1const $as-x64-ds
38 as-1const $as-x64-es
100 as-1const $as-x64-fs
101 as-1const $as-x64-gs
102 as-1const $as-x64-oso
103 as-1const $as-x64-aso

(%opcode %mode
  #f %size-override
  0 %rex
  0 %modrm
  #f %sib
  #f %disp
  #f %imm

  #f %disp-s
  #f %disp-f
  #f %imm-s
  #f %imm-f

  dup %oreg ^as-x64-registers assoc-ref %reg
  dup %orm ^as-x64-registers assoc-ref %rm

  if (^orm 'sib eq) (
    ^as-x64-registers assoc-ref %base
    ^as-x64-registers assoc-ref %index
    ^as-x64-radicies assoc-ref %scale

    if (^base 3 >>) (
      ^rex 65 binary-or $rex
      ^base 7 binary-and $base
    ) endif

    if (^index 3 >>) (
      ^rex 66 binary-or $rex
      ^index 7 binary-and $index
    ) endif

    ^scale 6 << ^index 3 << binary-or ^base binary-or $sib
  ) endif

  ; special case for registers like sil
  if (^oreg as-x64-modes assoc-ref 4 eq ^orm as-x64-modes assoc-ref 4 eq or) (
    ^rex 64 binary-or $rex
  ) endif

  ; this will be an AMD64 register like r8 or r15
  if (^reg 3 >>) (
    ^rex 72 binary-or $rex
    ^reg 7 binary-and $reg
  ) endif

  if (^rm 3 >>) (
    ^rex 65 binary-or $rex
    ^rm 7 binary-and $rm
  ) endif

  ; rex extension
  if (^oreg as-x64-modes assoc-ref 3 eq) (
    ^rex 72 binary-or $rex
  ) endif

  ; size override
  if (^oreg as-x64-modes assoc-ref 1 eq) (
    #t $size-override
  ) endif

  ; now we actually check the mode
  if (^mode 'r eq) (
    ^reg 3 << 192 binary-or ^rm binary-or $modrm
  ) endif

  if (^mode '[] eq) (
    ; sp and r12 are handeled by SIB 
    if (^rm dup 4 eq swap 5 eq or ^orm 'sib neq and) (
      ^rm 32 binary-or $sib
    ) endif

    ^reg 3 << ^rm binary-or $modrm
  ) endif

  if (^mode '[+d] eq) (
    $disp

    ; sp is handeled by SIB
    if (^rm 4 eq ^orm 'sib neq and) (
      36 $sib
    ) endif

    if (^disp as-disp8?) (
      ; disp8 is enough
      1 $disp-s
      ^! $disp-f

      ^reg 3 << 64 binary-or ^rm binary-or $modrm
    ) else (
      ; we need disp32
      4 $disp-s
      ^!d $disp-f

      ^reg 3 << 128 binary-or ^rm binary-or $modrm
    ) endif
  ) endif

  ;;; now we assemble the final instruction
  0 alloc %res

  if (^size-override) (
    102 nb>b join
  ) endif

  if (^rex 64 binary-and) (
    ^res ^rex nb>b join $res
  ) endif

  ^res ^opcode nb>b join ^modrm nb>b join $res

  if (^sib #f neq) (
    ^res ^sib nb>b join $res
  ) endif

  if (^disp #f neq) (
    ^disp-s alloc %buf
    ^disp 0 ^buf disp-f
    ^res ^buf join $res
  ) endif

  if (^imm #f neq) (
    ^imm-s alloc %buf
    ^imm ^buf imm-s
    ^res ^buf join $res
  ) endif

  ^res
) $as-x64-build

(%v 4 nb>b join ^v nb>b join) $as-x64-add-al
(%v 5 nb>b join ^v nw>b join) $as-x64-add-ax
(%v 102 nb>b join 5 nb>b join ^v nd>b join) $as-x64-add-eax
(%v 72 nb>b join 5 nb>b join ^v nd>b join) $as-x64-add-rax

(%ri-func %base
  (%r
      ; 8 bits
      if (^r ^as-x64-modes assoc-ref 0 eq) (
        ^r swap ^base 2 + as-x64-build
      ) endif

      ; 16 bits
      if (^r ^as-x64-modes assoc-ref 1 eq) (
        ^r swap ^base 3 + as-x64-build
      ) endif

      ; 32 bits
      if (^r ^as-x64-modes assoc-ref 2 eq) (
        ^r swap ^base 3 + as-x64-build
      ) endif

      ; 64 bits
      if (^r ^as-x64-modes assoc-ref 3 eq) (
        ^r swap ^base 3 + as-x64-build
      ) endif

      ; 8 bits but also special
      if (^r ^as-x64-modes assoc-ref 4 eq) (
        ^r swap ^base 2 + as-x64-build
      ) endif

      join
  )

  (%r
      ; 8 bits
      if (^r ^as-x64-modes assoc-ref 0 eq) (
        ^r swap ^base as-x64-build
      ) endif

      ; 16 bits
      if (^r ^as-x64-modes assoc-ref 1 eq) (
        ^r swap ^base 1 + as-x64-build
      ) endif

      ; 32 bits
      if (^r ^as-x64-modes assoc-ref 2 eq) (
        ^r swap ^base 1 + as-x64-build
      ) endif

      ; 64 bits
      if (^r ^as-x64-modes assoc-ref 3 eq) (
        ^r swap ^base 1 + as-x64-build
      ) endif

      ; 8 bits but also special
      if (^r ^as-x64-modes assoc-ref 4 eq) (
        ^r swap ^base as-x64-build
      ) endif

      join
  )

  (%r %v
    ; ax is special
    if (^r 'al eq) (
      ^base 4 + nb>b ^v nb>b join
    ) endif

    if (^r 'ax eq) (
      if (^v as-disp8?) (
        102 nb>b ^r ^ri-func 'r 131 as-x64-build ^v nb>b join join
      ) else (
        102 nb>b ^base 4 + nb>b ^v nw>b join join
      ) endif
    ) endif

    if (^r 'eax eq) (
      if (^v as-disp8?) (
        ^r ^ri-func 'r 131 as-x64-build ^v nb>b join
      ) else (
        ^base 5 + nb>b ^v nd>b join
      ) endif
    ) endif

    if (^r 'rax eq) (
      if (^v as-disp8?) (
        72 nb>b ^r ^ri-func 'r 131 as-x64-build ^v nb>b join join
      ) else (
        72 nb>b ^base 5 + nb>b ^v nd>b join join
      ) endif
    ) endif

    ; 8 bits
    if (^r ^as-x64-modes assoc-ref 0 eq ^r 'al neq and) (
      ^r ^ri-func 'r 128 as-x64-build ^v nb>b join
    ) endif

    ; 16 bits
    if (^r ^as-x64-modes assoc-ref 1 eq ^r 'ax neq and) (
      if (^v as-disp8?) (
        102 nb>b ^r ^ri-func 'r 131 as-x64-build ^v nb>b join join
      ) else (
        102 nb>b ^r ^ri-func 'r 129 as-x64-build ^v nw>b join join
      ) endif
    ) endif

    ; 32 bits
    if (^r ^as-x64-modes assoc-ref 2 eq ^r 'eax neq and) (
      if (^v as-disp8?) (
        ^r ^ri-func 'r 131 as-x64-build ^v nb>b join
      ) else (
        ^r ^ri-func 'r 129 as-x64-build ^v nd>b
      ) endif
    ) endif

    ; 64 bits
    if (^r ^as-x64-modes assoc-ref 3 eq ^r 'rax neq and) (
      if (^v as-disp8?) (
        72 nb>b ^r ^ri-func 'r 131 as-x64-build ^v nb>b join join
      ) else (
        72 nb>b ^r ^ri-func 'r 129 as-x64-build ^v nd>b join join
      ) endif
    ) endif

    ; 8 bits but also special
    if (^r ^as-x64-modes assoc-ref 4 eq) (
      ^r ^ri-func 'r 128 as-x64-build ^v nb>b join
    ) endif

    join
  )
) $as-x64-simpleop

0 'al as-x64-simpleop $as-x64-add-ri $as-x64-add-mr $as-x64-add-rm
40 'ah as-x64-simpleop $as-x64-sub-ri $as-x64-sub-mr $as-x64-sub-rm
32 'dl as-x64-simpleop $as-x64-and-ri $as-x64-and-mr $as-x64-and-rm
8 'cl as-x64-simpleop $ax-x64-or-ri $as-x64-or-mr $as-x64-or-rm
48 'ch as-x64-simpleop $ax-x64-xor-ri $as-x64-xor-mr $as-x64-xor-rm
