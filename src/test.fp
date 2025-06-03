;;; sanity
'(115 97 110 105 116 121) test-unit
#t test-assert
42 42 test-asserteq

;;; arithmetic
'(97 114 105 116 104 109 101 116 105 99) test-unit

4 2 + 6 test-asserteq
6 4 - 2 test-asserteq
4 6 - -2 test-asserteq
9223372036854775807 1 + -9223372036854775808 test-asserteq
-9223372036854775808 1 - 9223372036854775807 test-asserteq

10 5 / 2 test-asserteq
10 3 / 3 test-asserteq
-5 2 / -2 test-asserteq
10 -2 / -5 test-asserteq
-10 -5 / 2 test-asserteq
10 3 mod 1 test-asserteq
9 3 mod 0 test-asserteq
-1 3 mod 2 test-asserteq
69 -5 mod -1 test-asserteq
-11 -3 mod -2 test-asserteq
18446744069414584320 9 umod 3 test-asserteq
9223372036854775877 4611686018427387904 umod 69 test-asserteq

;;; x64 assembler
'(120 54 52 32 97 115 115 101 109 98 108 101 114) test-unit

0 alloc -1 'rax as-x64-add-ri '(72 131 192 255) test-assertbeq
0 alloc 105 'rcx as-x64-add-ri '(72 131 193 105) test-assertbeq
0 alloc 6969 'r9d as-x64-add-ri '(65 129 193 57 27 0 0) test-assertbeq
0 alloc 69 'sil as-x64-add-ri '(64 128 198 69) test-assertbeq

0 alloc 'rsp '[] 'al as-x64-add-mr '(0 4 36) test-assertbeq
0 alloc 'r8 '[] 'eax as-x64-add-rm '(65 3 0) test-assertbeq
0 alloc 69 'rax '[+d] 'al as-x64-add-rm '(2 64 69) test-assertbeq
0 alloc 4 'rcx 'r8 'sib '[] 'sil as-x64-add-rm '(65 2 52 136) test-assertbeq

0 alloc 'rsp '[] 'al as-x64-sub-rm '(42 4 36) test-assertbeq
0 alloc 69 8 'r9 'rcx 'sib '[+d] 'dx as-x64-sub-rm '(102 66 43 84 201 69) test-assertbeq

0 alloc 4 'r8 'rcx 'sib '[] 'rax as-x64-and-rm '(74 35 4 129) test-assertbeq

0 alloc 0 4 'r8 'zero 'sib '[+d] 'rax as-x64-and-rm '(74 35 4 133 0 0 0 0) test-assertbeq
