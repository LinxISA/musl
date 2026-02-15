#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

/*
 * Linx Linux syscall ABI:
 * - a0..a5: arguments
 * - a7: syscall number
 * - return in a0 (negative errno on failure)
 * - trap entry via `acrc 1`
 */
static inline long __linx_syscall(long n, long a0, long a1, long a2, long a3, long a4, long a5)
{
	long ret;

	__asm__ volatile(
		"c.movr %1, ->a0\n"
		"c.movr %2, ->a1\n"
		"c.movr %3, ->a2\n"
		"c.movr %4, ->a3\n"
		"c.movr %5, ->a4\n"
		"c.movr %6, ->a5\n"
		"c.movr %7, ->a7\n"
		"acrc 1\n"
		"c.bstop\n"
		"C.BSTART\n"
		"c.movr a0, ->%0\n"
		: "=r"(ret)
		: "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(n)
		: "a0", "a1", "a2", "a3", "a4", "a5", "a7", "memory");

	return ret;
}

static inline long __syscall0(long n)
{
	return __linx_syscall(n, 0, 0, 0, 0, 0, 0);
}

static inline long __syscall1(long n, long a0)
{
	return __linx_syscall(n, a0, 0, 0, 0, 0, 0);
}

static inline long __syscall2(long n, long a0, long a1)
{
	return __linx_syscall(n, a0, a1, 0, 0, 0, 0);
}

static inline long __syscall3(long n, long a0, long a1, long a2)
{
	return __linx_syscall(n, a0, a1, a2, 0, 0, 0);
}

static inline long __syscall4(long n, long a0, long a1, long a2, long a3)
{
	return __linx_syscall(n, a0, a1, a2, a3, 0, 0);
}

static inline long __syscall5(long n, long a0, long a1, long a2, long a3, long a4)
{
	return __linx_syscall(n, a0, a1, a2, a3, a4, 0);
}

static inline long __syscall6(long n, long a0, long a1, long a2, long a3, long a4, long a5)
{
	return __linx_syscall(n, a0, a1, a2, a3, a4, a5);
}

#define VDSO_USEFUL
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_4.15"

#define IPC_64 0
