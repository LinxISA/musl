	.text
	.global vfork
	.type vfork,@function
vfork:
	C.BSTART.STD
	addiw	zero, 220,	->a7
	addiw	zero, 0x4111,	->a0
	c.movr	sp,	->a1
	acrc 1
	.hidden __syscall_ret
	BSTART	CALL, __syscall_ret, ra=1f
	C.BSTOP
1:
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
