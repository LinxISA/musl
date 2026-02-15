	.text
	.global __longjmp
	.global _longjmp
	.global longjmp
	.type __longjmp,@function
	.type _longjmp,@function
	.type longjmp,@function
__longjmp:
_longjmp:
longjmp:
	C.BSTART.STD
	ldi	[a0, 0],	->s0
	ldi	[a0, 8],	->s1
	ldi	[a0, 16],	->s2
	ldi	[a0, 24],	->s3
	ldi	[a0, 32],	->s4
	ldi	[a0, 40],	->s5
	ldi	[a0, 48],	->s6
	ldi	[a0, 56],	->s7
	ldi	[a0, 64],	->s8
	ldi	[a0, 72],	->sp
	ldi	[a0, 80],	->ra
	c.movr	a1,	->a0
	C.BSTART.STD	RET
