#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

/*
 * Bring-up fallback: the Linx Linux syscall trap ABI is still evolving.
 * Keep compile/link coverage by returning -ENOSYS until the final trap
 * instruction and register contract are fixed.
 */
#define __linx_enosys (-38)

static inline long __syscall0(long n)
{
	(void)n;
	return __linx_enosys;
}

static inline long __syscall1(long n, long a)
{
	(void)n;
	(void)a;
	return __linx_enosys;
}

static inline long __syscall2(long n, long a, long b)
{
	(void)n;
	(void)a;
	(void)b;
	return __linx_enosys;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	(void)n;
	(void)a;
	(void)b;
	(void)c;
	return __linx_enosys;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	(void)n;
	(void)a;
	(void)b;
	(void)c;
	(void)d;
	return __linx_enosys;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	(void)n;
	(void)a;
	(void)b;
	(void)c;
	(void)d;
	(void)e;
	return __linx_enosys;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	(void)n;
	(void)a;
	(void)b;
	(void)c;
	(void)d;
	(void)e;
	(void)f;
	return __linx_enosys;
}

#define VDSO_USEFUL
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_4.15"

#define IPC_64 0
