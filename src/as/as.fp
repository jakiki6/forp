(l>b %x (^x join)) $as-const
(nb>b %x (^x join)) $as-1const
(0 alloc) $as-begin
(dup -128 < swap 127 > or not) $as-disp8?
(dup -32768 < swap 32767 > or not) $as-disp16?
