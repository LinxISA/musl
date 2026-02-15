# Bring-up mode:
# - phase-a: allow minimal temporary TU exclusions for known LLVM backend blockers.
# - phase-b: strict mode; exclusions are forbidden.
LINX_MUSL_MODE ?= phase-a

ifneq ($(LINX_MUSL_MODE),phase-b)
LINX_MUSL_EXTRA_EXCLUDES ?=
ALL_OBJS := $(filter-out \
	obj/src/locale/catopen.o \
	obj/src/locale/dcngettext.o \
	obj/src/misc/nftw.o \
	obj/src/misc/realpath.o \
	$(LINX_MUSL_EXTRA_EXCLUDES), \
	$(ALL_OBJS))
endif
