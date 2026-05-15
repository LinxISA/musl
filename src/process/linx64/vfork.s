	.text
	.global vfork
	.type vfork,@function
vfork:
	C.BSTART.STD
	addiw	zero, 220,	->a7
	lui	4,	->a0
	addi	a0, 273,	->a0
	c.movr	sp,	->a1
	acrc 1
	.hidden __syscall_ret
	BSTART	CALL, __syscall_ret
	setret	1f
	C.BSTOP
1:
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
