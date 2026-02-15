#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__("" ::: "memory");
}

#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	int old = *p;
	if (old == t) *p = s;
	return old;
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	volatile void **pp = (volatile void **)p;
	void *old = *pp;
	if (old == t) *pp = s;
	return old;
}
