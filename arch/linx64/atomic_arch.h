#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__("" ::: "memory");
}

/*
 * Use lock-free LR/SC loops for CAS. The current QEMU/Linux bring-up stack
 * implements LR/SC atomics in user mode, while HL.CAS* is not enabled yet.
 * Emit raw instruction bytes because the asm parser cannot reliably parse
 * the full Linx atomic field syntax in inline asm.
 *
 * Register bindings:
 *   lr.*: a0 = address, result in a0
 *   sc.*: a0 = address, a1 = value, result (0=success) in a0
 */
#define LINX_LR_W_A0_TO_A0  ".byte 0x0b,0x01,0x01,0x26"
#define LINX_SC_W_A1_A0_TO_A0 ".byte 0x0b,0x91,0x21,0x26"
#define LINX_LR_D_A0_TO_A0  ".byte 0x0b,0x01,0x01,0x36"
#define LINX_SC_D_A1_A0_TO_A0 ".byte 0x0b,0x91,0x21,0x36"

static inline int __linx_lr_w(volatile int *p)
{
	register long addr __asm__("a0") = (long)p;
	__asm__ __volatile__(
		LINX_LR_W_A0_TO_A0
		: "+r"(addr)
		:
		: "memory");
	return (int)addr;
}

static inline int __linx_sc_w(volatile int *p, int v)
{
	register long addr __asm__("a0") = (long)p;
	register long val __asm__("a1") = (long)v;
	__asm__ __volatile__(
		LINX_SC_W_A1_A0_TO_A0
		: "+r"(addr)
		: "r"(val)
		: "memory");
	return (int)addr;
}

static inline unsigned long __linx_lr_d(volatile void *p)
{
	register long addr __asm__("a0") = (long)p;
	__asm__ __volatile__(
		LINX_LR_D_A0_TO_A0
		: "+r"(addr)
		:
		: "memory");
	return (unsigned long)addr;
}

static inline int __linx_sc_d(volatile void *p, unsigned long v)
{
	register long addr __asm__("a0") = (long)p;
	register long val __asm__("a1") = (long)v;
	__asm__ __volatile__(
		LINX_SC_D_A1_A0_TO_A0
		: "+r"(addr)
		: "r"(val)
		: "memory");
	return (int)addr;
}

#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	int old;
	do {
		old = __linx_lr_w(p);
		if (old != t) break;
	} while (__linx_sc_w(p, s) != 0);
	return old;
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	unsigned long expect = (unsigned long)t;
	unsigned long old;
	do {
		old = __linx_lr_d((volatile void *)p);
		if (old != expect) break;
	} while (__linx_sc_d((volatile void *)p, (unsigned long)s) != 0);
	return (void *)old;
}
