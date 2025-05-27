; https://wiki.osdev.org/X86-64_Instruction_Encoding#Registers
'(
  (al 0) (ax 0) (eax 0) (rax 0) (es 0) (cr0 0)
  (cl 1) (cx 1) (ecx 1) (rcx 1) (cs 1)
  (dl 2) (dx 2) (edx 2) (rdx 2) (ss 2) (cr2 2)
  (bl 3) (bx 3) (ebx 3) (rbx 3) (ds 3) (cr3 3)
  (ah 4) (spl 20) (sp 4) (esp 4) (rsp 4) (fs 4) (cr4 4)
  (ch 5) (bpl 21) (bp 5) (ebp 5) (rbp 5) (gs 5)
  (dh 6) (sil 22) (si 6) (esi 6) (rsi 6)
  (bh 7) (dil 23) (di 7) (edi 7) (rdi 7)
  (r8l 8) (r8w 8) (r8d 8) (r8 8) (cr8 8)
  (r9l 9) (r9w 9) (r9d 9) (r9 9)
  (r10l 10) (r10w 10) (r10d 10) (r10 10)
  (r11l 11) (r11w 11) (r11d 11) (r11 11)
  (r12l 12) (r12w 12) (r12d 12) (r12 12)
  (r13l 13) (r13w 13) (r13d 13) (r13 13)
  (r14l 14) (r14w 14) (r14d 14) (r14 14)
  (r15l 15) (r15w 15) (r15d 15) (r15 15)
) $as-x64-register-table

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
  0 %rex
  0 %modrm
  #f %sib
  #f %disp
  #f %imm

  #f %disp-s
  #f %disp-f
  #f %imm-s
  #f %imm-f

  #f %reg
  #f %rm

  ; all cases of r/m consume these so let's factor them out
  if (^mode 'r/m eq ^mode '[r/m] eq or) (
    ^as-x64-register-table assoc-ref $reg
    ^as-x64-register-table assoc-ref $rm

    ; this will be a special 8 bit high register like sil or spl
    if (^reg 4 >>) (
      ^rex 64 binary-or $rex
      ^reg 15 binary-and $reg
    ) endif

    if (^rm 4 >>) (
      ^rex 64 binary-or $rex
      ^rm 15 binary-and $rm
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
  ) endif

  ; now we actually check the mode
  if (^mode 'r/m eq) (
    ^reg 3 << 192 binary-or ^rm binary-or $modrm
  ) endif

  if (^mode '[r/m] eq) (
    ; sp, bp, r12 and r13 are handled using SIB
    if (^rm dup 4 eq swap 5 eq or) (
      panic
    ) endif

    ^reg 3 << ^rm binary-or $modrm
  ) endif

  ;;; now we assemble the final instruction
  0 alloc %res

  if (^rex 64 binary-and) (
    ^res ^rex n>b join $res
  ) endif

  ^res ^opcode n>b join ^modrm n>b join $res

  if (^sib #f neq) (
    ^res ^sib n>b join $res
  ) endif

  if (^disp #f neq) (
    ^disp-s alloc %buf
    ^disp ^buf disp-f
    ^res ^buf join $res
  ) endif

  if (^imm #f neq) (
    ^imm-s alloc %buf
    ^imm ^buf imm-s
    ^res ^buf join $res
  ) endif

  ^res
) $as-x64-build

0 alloc as-x64-ret

'bl 'sil 'r/m 0 as-x64-build join
'bl 'al '[r/m] 0 as-x64-build join

$buf
^buf bs 0 range (^buf @ putc) each
