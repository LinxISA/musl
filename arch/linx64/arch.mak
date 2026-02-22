# Bring-up mode:
# - phase-a: allow minimal temporary TU exclusions for known LLVM backend blockers.
# - phase-b: strict mode; exclusions are forbidden.
# - phase-c: strict mode with hosted ABI packaging.
LINX_MUSL_MODE ?= phase-b

ifeq ($(LINX_MUSL_MODE),phase-a)
LINX_MUSL_EXTRA_EXCLUDES ?=
ALL_OBJS := $(filter-out \
	$(LINX_MUSL_EXTRA_EXCLUDES), \
	$(ALL_OBJS))
endif
