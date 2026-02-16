#include <signal.h>

#define ELF_NGREG 25
#define ELF_NFPREG 33
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];
typedef __linx_mc_fp_state elf_fpregset_t;
