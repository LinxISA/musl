#define a_barrier a_barrier
static inline void a_barrier()
{
	__sync_synchronize();
}

#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	return __sync_val_compare_and_swap(p, t, s);
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	return __sync_val_compare_and_swap((volatile void **)p, t, s);
}
