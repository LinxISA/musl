# Temporary bring-up workaround:
# The current Linx LLVM backend crashes on these locale translation units.
# Keep the static-lib gate moving by excluding them until backend fixes land.
ALL_OBJS := $(filter-out \
	obj/src/locale/catopen.o \
	obj/src/locale/dcngettext.o \
	obj/src/locale/catopen.lo \
	obj/src/locale/dcngettext.lo, \
	$(ALL_OBJS))
