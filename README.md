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

## PTO ISA identity

The Linx loader requires the exact PTO ISA 0.58.3 ELF note before startup,
dependency constructors, or `dlopen` constructors run. Missing notes are
rejected by the closure policy; old 0.58.1, malformed, trailing-NUL, and
conflicting descriptors fail closed. Byte-identical duplicate notes remain
valid.

The ELF descriptor contains only the release ABI fields required by the PTO
release manifest. Exact content and source provenance are locked separately in
`tools/linx/pto_isa_identity.lock.json`:

- PTO-SPEC commit `e599a3d36ebfad43362ff591ea5e128816c684c7`;
- tree `abb6899d2e664e378ac9c1b77062670daa4d31b4`;
- content SHA-256 `f299fe3d256c5d071e57bb4aaa2be2de2e4a386ae090048df1f73ae92d392678`;
- encoding projection SHA-256 `8a48b80e04484c70870f155bf9efc79d2a805cf99e809f4e4e8a7e6a7eb34172`.

Run `python3 tools/linx/check_pto_isa_identity.py` before any target build.
The phase build script records this authority in its summary. It accepts an
explicit `LLVM_BIN` and intentionally does not pin a transient compiler topic
commit; release integration supplies the final reviewed toolchain.

## Related Docs
- `/Users/zhoubot/linx-isa/docs/project/navigation.md`
- `/Users/zhoubot/linx-isa/docs/bringup/libc_status.md`
- `/Users/zhoubot/linx-isa/docs/bringup/`
