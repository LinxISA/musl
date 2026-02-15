#include <stdint.h>

/*
 * Linx thread pointer (TP) is modeled in SSR 0x0000.
 * Keep the accessors in C so pthread_arch.h can stay simple.
 */
#define LINX_SSR_TP 0x0000

uintptr_t __linx_get_tp(void)
{
	uintptr_t tp;

	__asm__ volatile("ssrget %1, ->%0"
			 : "=r"(tp)
			 : "i"(LINX_SSR_TP)
			 : "memory");
	return tp;
}

int __set_thread_area(void *p)
{
	__asm__ volatile("ssrset %0, %1"
			 :
			 : "r"(p), "i"(LINX_SSR_TP)
			 : "memory");
	return 0;
}
