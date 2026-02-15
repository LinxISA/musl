#include <stdint.h>

static uintptr_t __linx_tp_value;

uintptr_t __linx_get_tp(void)
{
	return __linx_tp_value;
}

int __set_thread_area(void *p)
{
	__linx_tp_value = (uintptr_t)p;
	return 0;
}
