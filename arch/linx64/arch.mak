# Bring-up mode:
# - phase-a: allow minimal temporary TU exclusions for known LLVM backend blockers.
# - phase-b: strict mode; exclusions are forbidden.
LINX_MUSL_MODE ?= phase-b

ifneq ($(LINX_MUSL_MODE),phase-b)
LINX_MUSL_EXTRA_EXCLUDES ?=
ALL_OBJS := $(filter-out \
	$(LINX_MUSL_EXTRA_EXCLUDES), \
	$(ALL_OBJS))
endif
