  .text
  .globl longjmp
  .type longjmp, @function
  .align 1
longjmp:
.Ltmp1:
  C.BSTART
  ldi.u	[a0, 0],->s0
  ldi.u	[a0, 8],->s1
  ldi.u	[a0, 16],->s2
  ldi.u	[a0, 24],->s3
  ldi.u	[a0, 32],->s4
  ldi.u	[a0, 40],->s5
  ldi.u	[a0, 48],->s6
  ldi.u	[a0, 56],->s7
  ldi.u	[a0, 64],->s8
  ldi.u	[a0, 72],->sp
  ldi.u	[a0, 80],->ra
.Ltmp2:
  C.BSTART RET
  cmp.eqi	  a1, 0, ->t
  add	      t#1, a1, ->a0
  setc.tgt	ra
  C.BSTOP
.Lfunc_end0:
  .size longjmp, .-longjmp
