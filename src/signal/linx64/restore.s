	.text
	.global __restore
	.hidden __restore
	.type __restore,@function
__restore:
	.global __restore_rt
	.hidden __restore_rt
	.type __restore_rt,@function
__restore_rt:
	C.BSTART.STD
	addiw	zero, 139,	->a7
	acrc 1
	C.BSTART	DIRECT, __restore_rt
	C.BSTOP
