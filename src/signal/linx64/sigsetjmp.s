	.text
	.global sigsetjmp
	.global __sigsetjmp
	.type sigsetjmp,@function
	.type __sigsetjmp,@function
sigsetjmp:
__sigsetjmp:
	C.BSTART
	C.BSTART	COND, 1f
	setc.ne	a1, zero
	C.BSTOP
	C.BSTART	DIRECT, setjmp
	C.BSTOP
1:
	sdi	ra, [a0, 88]
	sdi	s0, [a0, 96]
	c.movr	a0,	->s0
	BSTART	CALL, setjmp, ra=2f
	C.BSTOP
2:
	c.movr	a0,	->a1
	c.movr	s0,	->a0
	ldi	[a0, 96],	->s0
	ldi	[a0, 88],	->ra
	.hidden __sigsetjmp_tail
	C.BSTART	DIRECT, __sigsetjmp_tail
	C.BSTOP
