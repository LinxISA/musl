#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__("" ::: "memory");
}

extern volatile int __linx_atomic_lockword;

/*
 * Raw SWAPW encoding for:
 *   swapw [a0], a1, ->a0
 *
 * Linx asm parser support for aq/rl/f atomic fields is still bring-up limited.
 * Emit the instruction word directly so we can rely on hardware atomic swap.
 */
#define LINX_SWAPW_A0_A1_TO_A0 0x2031610b
#define LINX_STR1(x) #x
#define LINX_STR(x) LINX_STR1(x)

static inline int __linx_atomic_swapw(volatile int *p, int v)
{
	register long addr __asm__("a0") = (long)p;
	register long val __asm__("a1") = (long)v;
	__asm__ __volatile__(
		".long " LINX_STR(LINX_SWAPW_A0_A1_TO_A0)
		: "+r"(addr)
		: "r"(val)
		: "memory");
	return (int)addr;
}

static inline void __linx_atomic_lock(void)
{
	while (__linx_atomic_swapw(&__linx_atomic_lockword, 1) != 0)
		__asm__ __volatile__("" ::: "memory");
	a_barrier();
}

static inline void __linx_atomic_unlock(void)
{
	a_barrier();
	__linx_atomic_lockword = 0;
	a_barrier();
}

#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	int old;
	__linx_atomic_lock();
	old = *p;
	if (old == t)
		*p = s;
	__linx_atomic_unlock();
	return old;
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	volatile void **pp = (volatile void **)p;
	void *old;
	__linx_atomic_lock();
	old = *pp;
	if (old == t)
		*pp = s;
	__linx_atomic_unlock();
	return old;
}
