	.section .init
	.global _init
	.type _init,%function
	.align 1
_init:
	C.BSTART RET
	addi	 ra, 0, ->t
	setc.tgt t#1
	C.BSTOP

	.section .fini
	.global _fini
	.type _fini,%function
	.align 1
_fini:
	C.BSTART RET
	addi	 ra, 0, ->t
	setc.tgt t#1
	C.BSTOP