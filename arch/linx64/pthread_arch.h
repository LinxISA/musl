static inline uintptr_t __get_tp()
{
	extern uintptr_t __linx_get_tp(void);
	return __linx_get_tp();
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0

#define DTP_OFFSET 0x800

#define MC_PC sc_regs.regs[24]
