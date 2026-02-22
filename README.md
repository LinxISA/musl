# LinxISA musl libc

## Scope
`lib/musl` is the primary libc lane for LinxISA bring-up and SPEC-focused userspace/runtime validation.

## Upstream
- Repository: `https://github.com/LinxISA/musl`
- Merge-back target branch: `master`

## What This Submodule Owns
- LinxISA musl port (`arch/linx64`)
- Phase-based sysroot generation (`phase-a/b/c`)
- Bring-up libc used by AVS runtime and SPEC flows

## Canonical Build and Test Commands
Run from `/Users/zhoubot/linx-isa`.

```bash
MODE=phase-c bash /Users/zhoubot/linx-isa/lib/musl/tools/linx/build_linx64_musl.sh

python3 /Users/zhoubot/linx-isa/avs/qemu/run_musl_smoke.py \
  --mode phase-c \
  --link both \
  --qemu /Users/zhoubot/linx-isa/emulator/qemu/build/qemu-system-linx64
```

## LinxISA Integration Touchpoints
- Runtime lane and smoke tests in `/Users/zhoubot/linx-isa/avs/qemu`
- C/C++ runtime overlay generation in `/Users/zhoubot/linx-isa/tools/build_linx_llvm_cpp_runtimes.sh`
- SPEC toolchain/sysroot dependency path

## Related Docs
- `/Users/zhoubot/linx-isa/docs/project/navigation.md`
- `/Users/zhoubot/linx-isa/docs/bringup/libc_status.md`
- `/Users/zhoubot/linx-isa/docs/bringup/`
