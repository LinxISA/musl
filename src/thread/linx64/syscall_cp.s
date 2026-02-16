	.text
	.global __cp_begin
	.hidden __cp_begin
	.global __cp_end
	.hidden __cp_end
	.global __cp_cancel
	.hidden __cp_cancel
	.global __syscall_cp_asm
	.hidden __syscall_cp_asm
	.hidden __cancel
	.type __syscall_cp_asm,@function
__syscall_cp_asm:
	C.BSTART.STD
__cp_begin:
	C.BSTART	COND, __cp_cancel
	lwi	[a0, 0],	->x0
	setc.ne	x0, zero
	C.BSTOP
	c.movr	a1,	->x3
	c.movr	a2,	->a0
	c.movr	a3,	->a1
	c.movr	a4,	->a2
	c.movr	a5,	->a3
	c.movr	a6,	->a4
	c.movr	a7,	->a5
	c.movr	x3,	->a7
	acrc 1
	c.bstop
	C.BSTART
__cp_end:
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
__cp_cancel:
	BSTART	CALL, __cancel, ra=1f
	C.BSTOP
1:
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
