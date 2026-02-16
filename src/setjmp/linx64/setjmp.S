	.text
	.global __setjmp
	.global _setjmp
	.global setjmp
	.type __setjmp,@function
	.type _setjmp,@function
	.type setjmp,@function
__setjmp:
_setjmp:
setjmp:
	C.BSTART.STD
	sdi	s0, [a0, 0]
	sdi	s1, [a0, 8]
	sdi	s2, [a0, 16]
	sdi	s3, [a0, 24]
	sdi	s4, [a0, 32]
	sdi	s5, [a0, 40]
	sdi	s6, [a0, 48]
	sdi	s7, [a0, 56]
	sdi	s8, [a0, 64]
	sdi	sp, [a0, 72]
	sdi	ra, [a0, 80]
	c.movr	zero,	->a0
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
