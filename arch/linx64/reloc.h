#define LDSO_ARCH "linx64"

#define TPOFF_K 0

#define REL_SYMBOLIC    R_LINX_64
#define REL_GOT         R_LINX_GLOB_DAT
#define REL_PLT         R_LINX_JUMP_SLOT
#define REL_RELATIVE    R_LINX_RELATIVE
#define REL_COPY        R_LINX_COPY
#define REL_DTPMOD      R_LINX_TLS_DTPMOD64
#define REL_DTPOFF      R_LINX_TLS_DTPREL64
#define REL_TPOFF       R_LINX_TLS_TPREL64
#define REL_TLSDESC     R_LINX_TLSDESC
#define DL_SKIP_VDSO    1

#define CRTJMP(pc,sp) do { \
	register void *__pc __asm__("a0") = (void *)(pc); \
	register void *__nsp __asm__("a1") = (void *)(sp); \
	__asm__ __volatile__( \
		"c.movr a1, ->sp\n" \
		"C.BSTART IND\n" \
		"setc.tgt a0\n" \
		"C.BSTOP\n" \
		: "+r"(__pc) \
		: "r"(__nsp) \
		: "memory"); \
} while (0)
