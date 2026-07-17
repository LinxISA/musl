
#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	register long old __asm__("a0") = (long)p;
	register long expect __asm__("a1") = (long)t;
	register long desired __asm__("a2") = (long)s;
	__asm__ __volatile__(
		"casw.aqrl [a0], a1, a2, ->a0"
		: "+r"(old)
		: "r"(expect), "r"(desired)
		: "memory");
	return (int)old;
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	register unsigned long old __asm__("a0") = (unsigned long)p;
	register unsigned long expect __asm__("a1") = (unsigned long)t;
	register unsigned long desired __asm__("a2") = (unsigned long)s;
	__asm__ __volatile__(
		"casd.aqrl [a0], a1, a2, ->a0"
		: "+r"(old)
		: "r"(expect), "r"(desired)
		: "memory");
	return (void *)old;
}
