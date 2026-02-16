	.text
	.global dlsym
	.hidden __dlsym
	.type dlsym,@function
dlsym:
	C.BSTART.STD
	c.movr	ra,	->a2
	BSTART	CALL, __dlsym, ra=1f
	C.BSTOP
1:
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
