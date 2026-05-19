  .globl setjmp
  .type setjmp, @function
  .align 1
setjmp:
  C.BSTART RET
  sdi.u	s0, [a0, 0]
  sdi.u	s1, [a0, 8]
  sdi.u	s2, [a0, 16]
  sdi.u	s3, [a0, 24]
  sdi.u	s4, [a0, 32]
  sdi.u	s5, [a0, 40]
  sdi.u	s6, [a0, 48]
  sdi.u	s7, [a0, 56]
  sdi.u	s8, [a0, 64]
  sdi.u	sp, [a0, 72]
  sdi.u	ra, [a0, 80]
  addi	zero,0,->a0
  setc.tgt	ra
  C.BSTOP
  .size setjmp, .-setjmp