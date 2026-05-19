  .global __restore
  .global __restore_rt
  .type __restore, @function
  .type __restore_rt, @function
  .align 1
__restore:
__restore_rt:
  C.BSTART.AUX
  addi	zero, 139,->t
  addi	t#1, 0, ->x1
  acrc 1
  C.BSTOP
