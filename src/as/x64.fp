; https://wiki.osdev.org/X86-64_Instruction_Encoding#Registers
'(
  (al 0) (ax 0) (eax 0) (rax 0) (es 0) (cr0 0)
  (cl 1) (cx 1) (ecx 1) (rcx 1) (cs 1)
  (dl 2) (dx 2) (edx 2) (rdx 2) (ss 2) (cr2 2)
  (bl 3) (bx 3) (ebx 3) (rbx 3) (ds 3) (cr3 3)
  (ah 4) (spl 4) (sp 4) (esp 4) (rsp 4) (fs 4) (cr4 4)
  (ch 5) (bpl 5) (bp 5) (ebp 5) (rbp 5) (gs 5)
  (dh 6) (sil 6) (si 6) (esi 6) (rsi 6)
  (bh 7) (dil 7) (di 7) (edi 7) (rdi 7)
  (r8l 8) (r8w 8) (r8d 8) (r8 8) (cr8 8)
  (r9l 9) (r9w 9) (r9d 9) (r9 9)
  (r10l 10) (r10w 10) (r10d 10) (r10 10)
  (r11l 11) (r11w 11) (r11d 11) (r11 11)
  (r12l 12) (r12w 12) (r12d 12) (r12 12)
  (r13l 13) (r13w 13) (r13d 13) (r13 13)
  (r14l 14) (r14w 14) (r14d 14) (r14 14)
  (r15l 15) (r15w 15) (r15d 15) (r15 15)
) $as-x64-register-table

'(195) as-const $as-x64-ret
'(240) as-const $as-x64-lock
'(242) as-const dup $as-x64-repne $as-x64-repnz
'(243) as-const dup dup $as-x64-rep $as-x64-repne $as-x64-repnz
'(46) as-const $as-x64-cs
'(54) as-const $as-x64-ss
'(62) as-const $as-x64-ds
'(38) as-const $as-x64-es
'(100) as-const $as-x64-fs
'(101) as-const $as-x64-gs
'(102) as-const $as-x64-oso
'(103) as-const $as-x64-aso

(64 binary-or swap 1 << binary-or swap 2 << binary-or swap 4 << binary-or #f swap cons l>b join) $as-x64-rex

0 alloc as-x64-ret

$buf
^buf bs 0 range (^buf @ putc) each
