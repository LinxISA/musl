	.text
	.global __clone
	.hidden __clone
	.type __clone,@function
__clone:
	C.BSTART.STD
	andi	a1, -16,	->a1
	subi	a1, 16,	->a1
	sdi	a0, [a1, 0]
	sdi	a3, [a1, 8]
	c.movr	a2,	->a0
	c.movr	a4,	->a2
	c.movr	a5,	->a3
	c.movr	a6,	->a4
	addiw	zero, 220,	->a7
	acrc 1
	C.BSTART	COND, 1f
	setc.eq	a0, zero
	C.BSTOP
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
1:
	ldi	[sp, 0],	->a1
	ldi	[sp, 8],	->a0
	addtpc	2f,	->ra
	addi	ra, 2f,	->ra
	C.BSTART	IND
	setc.tgt	a1
	C.BSTOP
2:
	addiw	zero, 93,	->a7
	acrc 1
	C.BSTART	DIRECT, 2b
	C.BSTOP
