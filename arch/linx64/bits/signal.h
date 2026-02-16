#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
# define MINSIGSTKSZ 2048
# define SIGSTKSZ 8192
#endif

#define LINX_NGREG 25

typedef struct {
	unsigned long regs[LINX_NGREG];
} __linx_user_pt_regs;

typedef struct {
	unsigned long long f[32];
	unsigned int fcsr;
	unsigned int __reserved;
} __linx_mc_fp_state;

typedef struct mcontext_t {
	__linx_user_pt_regs sc_regs;
} mcontext_t;

#if defined(_GNU_SOURCE)
#define REG_SP 1
#define REG_A0 2
#define REG_RA 10
#define REG_S0 11
#define REG_S1 12
#define REG_S2 13
#define REG_PC 24
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
typedef unsigned long greg_t;
typedef unsigned long gregset_t[LINX_NGREG];
typedef __linx_mc_fp_state fpregset_t;
struct sigcontext {
	__linx_user_pt_regs sc_regs;
};
#endif

struct sigaltstack {
	void *ss_sp;
	int ss_flags;
	size_t ss_size;
};

typedef struct __ucontext
{
	unsigned long uc_flags;
	struct __ucontext *uc_link;
	stack_t uc_stack;
	sigset_t uc_sigmask;
	unsigned char __unused[1024/8 - sizeof(sigset_t)];
	mcontext_t uc_mcontext;
} ucontext_t;

#define SA_NOCLDSTOP 1
#define SA_NOCLDWAIT 2
#define SA_SIGINFO   4
#define SA_RESTORER  0x04000000
#define SA_ONSTACK   0x08000000
#define SA_RESTART   0x10000000
#define SA_NODEFER   0x40000000
#define SA_RESETHAND 0x80000000

#endif

#define SIGHUP     1
#define SIGINT     2
#define SIGQUIT    3
#define SIGILL     4
#define SIGTRAP    5
#define SIGABRT    6
#define SIGIOT     SIGABRT
#define SIGBUS     7
#define SIGFPE     8
#define SIGKILL    9
#define SIGUSR1   10
#define SIGSEGV   11
#define SIGUSR2   12
#define SIGPIPE   13
#define SIGALRM   14
#define SIGTERM   15
#define SIGSTKFLT 16
#define SIGCHLD   17
#define SIGCONT   18
#define SIGSTOP   19
#define SIGTSTP   20
#define SIGTTIN   21
#define SIGTTOU   22
#define SIGURG    23
#define SIGXCPU   24
#define SIGXFSZ   25
#define SIGVTALRM 26
#define SIGPROF   27
#define SIGWINCH  28
#define SIGIO     29
#define SIGPOLL   SIGIO
#define SIGPWR    30
#define SIGSYS    31
#define SIGUNUSED SIGSYS

#define _NSIG     65
