
#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	// TODO:waiting for the real implementation of atomic Compare-and-Swap
	*p = s;
	return t;
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	// TODO:waiting for the real implementation of atomic Compare-and-Swap with pointer
	assert(0 && " wait to fix a_cas_p");
}
