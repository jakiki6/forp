as-begin
  86 nb>b join                  ; push rsi
  'rsi '[] 'rsi as-x64-mov-rm
  8 'rsi '[+d] 'rsi as-x64-mov-rm
  8 'rsi as-x64-add-ri
  'rdi 'r 'rdi as-x64-xor-rm
  'rax 'r 'rax as-x64-xor-rm
  1 'rax as-x64-add-ri
  'rdx 'r 'rdx as-x64-xor-rm
  1 'rdx as-x64-add-ri
  as-x64-syscall
  89 nb>b join                  ; pop rcx
  'rcx '[] 'rdi as-x64-mov-rm
  16 'rdi '[+d] 'rdi as-x64-mov-rm
  'rcx '[] 'rdi as-x64-mov-mr
  as-x64-ret
native $putc
