	.text
	.global __tlsdesc_static
	.hidden __tlsdesc_static
	.type __tlsdesc_static,@function
__tlsdesc_static:
	C.BSTART.STD
	ldi	[a0, 8],	->a0
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP

	.global __tlsdesc_dynamic
	.hidden __tlsdesc_dynamic
	.type __tlsdesc_dynamic,@function
__tlsdesc_dynamic:
	C.BSTART.STD
	ssrget	0x0000,	->x0
	ldi	[x0, -8],	->x1
	ldi	[a0, 8],	->a0
	ldi	[a0, 8],	->x2
	ldi	[a0, 0],	->a0
	slli	a0, 3,	->a0
	add	a0, x1,	->a0
	ldi	[a0, 0],	->a0
	add	a0, x2,	->a0
	sub	a0, x0,	->a0
	C.BSTART.STD	IND
	setc.tgt	ra
	C.BSTOP
