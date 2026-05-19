#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

static inline long
__internal_syscall(long n, long _a0, long _a1, long _a2, long _a3, long _a4, long _a5)
{
  __asm__ __volatile__(
	   "C.BSTART.AUX\n"
      "1:\n"
      "ori %0, 0, ->a0\n"
      "ori %1, 0, ->a1\n"
      "ori %2, 0, ->a2\n"
      "ori %3, 0, ->a3\n"
      "ori %4, 0, ->a4\n"
      "ori %5, 0, ->a5\n"
      "ori %6, 0, ->x1\n"
	   "acrc 1\n"
      "2:\n"
	   "C.BSTART\n"
      "ori a0, 0, ->%0\n"
      : "+r"(_a0)
      : "r"(_a1), "r"(_a2), "r"(_a3), "r"(_a4), "r"(_a5), "r"(n)
      : "a0", "a1", "a2", "a3", "a4", "a5", "x1");

  return _a0;
}

static inline long __syscall0(long n)
{
   return __internal_syscall(n, 0, 0, 0, 0, 0, 0);
}

static inline long __syscall1(long n, long a)
{
   return __internal_syscall(n, a, 0, 0, 0, 0, 0);
}

static inline long __syscall2(long n, long a, long b)
{
   return __internal_syscall(n, a, b, 0, 0, 0, 0);
}

static inline long __syscall3(long n, long a, long b, long c)
{
   return __internal_syscall(n, a, b, c, 0, 0, 0);
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
   return __internal_syscall(n, a, b, c, d, 0, 0);
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
   return __internal_syscall(n, a, b, c, d, e, 0);
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
   return __internal_syscall(n, a, b, c, d, e, f);
}

#define VDSO_USEFUL
/* We don't have a clock_gettime function.
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_2.6" */

#define IPC_64 0
