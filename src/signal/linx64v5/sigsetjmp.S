	.global sigsetjmp
	.global __sigsetjmp
	.type sigsetjmp, %function
	.type __sigsetjmp, %function
	.align 1
sigsetjmp:
__sigsetjmp:
.Ltmp1:
	BSTART COND .Ltmp3
	setc.ne	a1, zero

.Ltmp2.bstart:
	bstart.std direct setjmp

.Ltmp3:
	BSTART CALL setjmp
	sdi.u	ra, [a0, 208]
	sdi.u	s0, [a0, 224]
	add		a0, zero, ->s0

.Ltmp4:
	C.BSTART
	add		a0, zero, ->a1
	add		s0, zero, ->a0
	ldi.u	[a0, 224], ->s0
	ldi.u   [a0, 208], ->ra

.Ltmp5:
	bstart.std direct __sigsetjmp_tail
	C.BSTOP

