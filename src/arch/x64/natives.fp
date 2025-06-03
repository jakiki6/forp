as-begin
  86 nb>b join                  ; push rsi
  '(72 139 54) l>b join         ; mov rsi, qword [rsi]
  '(72 139 118 8) l>b join      ; mov rsi,[rsi+0x8]
  8 'rsi as-x64-add-ri
  'rdi 'r 'rdi as-x64-xor-rm
  'rax 'r 'rax as-x64-xor-rm
  1 'rax as-x64-add-ri
  'rdx 'r 'rdx as-x64-xor-rm
  1 'rdx as-x64-add-ri
  as-x64-syscall
  89 nb>b join                  ; pop rcx
  '(72 139 57) l>b join         ; mov rdi, qword [rcx]
  '(72 139 127 16) l>b join     ; mov rdi, qword [rdi + 16]
  '(72 137 57) l>b join         ; mov qword [rcx], rdi
  as-x64-ret
native $putc
