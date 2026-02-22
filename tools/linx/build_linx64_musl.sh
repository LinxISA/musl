#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-phase-b}"
case "$MODE" in
  phase-a|phase-b|phase-c) ;;
  *)
    echo "error: MODE must be phase-a, phase-b, or phase-c (got '$MODE')" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MUSL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

LINX_ISA_ROOT="${LINX_ISA_ROOT:-/Users/zhoubot/linx-isa}"
TARGET="${TARGET:-linx64-unknown-linux-musl}"
MALLOC_IMPL="${MALLOC_IMPL:-oldmalloc}"

LLVM_BIN="${LLVM_BIN:-/Users/zhoubot/llvm-project/build-linxisa-clang/bin}"
CLANG="${CLANG:-$LLVM_BIN/clang}"
AR="${AR:-$LLVM_BIN/llvm-ar}"
RANLIB="${RANLIB:-$LLVM_BIN/llvm-ranlib}"
NM="${NM:-$LLVM_BIN/llvm-nm}"
STRIP="${STRIP:-$LLVM_BIN/llvm-strip}"
READELF="${READELF:-$LLVM_BIN/llvm-readelf}"
LLVM_PROJECT_ROOT="${LLVM_PROJECT_ROOT:-$LINX_ISA_ROOT/compiler/llvm}"
COMPILER_RT_BUILTINS_DIR="${COMPILER_RT_BUILTINS_DIR:-$LLVM_PROJECT_ROOT/compiler-rt/lib/builtins}"

JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
OUT_ROOT="${OUT_ROOT:-$LINX_ISA_ROOT/out/libc/musl}"
BUILD_DIR="${BUILD_DIR:-$OUT_ROOT/build/$MODE}"
INSTALL_DIR="${INSTALL_DIR:-$OUT_ROOT/install/$MODE}"
LOG_DIR="${LOG_DIR:-$OUT_ROOT/logs}"
RUNTIME_DIR="${RUNTIME_DIR:-$OUT_ROOT/runtime/$MODE}"
RUNTIME_OBJ_DIR="$RUNTIME_DIR/obj"
RUNTIME_LIB="$RUNTIME_DIR/liblinx_builtin_rt.a"
PHASE_C_CRT_DIR="$RUNTIME_DIR/phase-c-crt"
PHASE_C_CRTBEGIN="$PHASE_C_CRT_DIR/crtbeginS.o"
PHASE_C_CRTEND="$PHASE_C_CRT_DIR/crtendS.o"

mkdir -p "$LOG_DIR" "$OUT_ROOT/build" "$OUT_ROOT/install"

CONFIG_LOG="$LOG_DIR/${MODE}-configure.log"
M2_LOG="$LOG_DIR/${MODE}-m2-libc-a.log"
M3_LOG="$LOG_DIR/${MODE}-m3-shared.log"
M3_BLOCKER_REPORT="$LOG_DIR/${MODE}-m3-blockers.md"
M3_NOTEXT_LOG="$LOG_DIR/${MODE}-m3-shared-notext-probe.log"
SUMMARY="$LOG_DIR/${MODE}-summary.txt"
RUNTIME_LOG="$LOG_DIR/${MODE}-runtime-builtins.log"

for exe in "$CLANG" "$AR" "$RANLIB" "$NM" "$STRIP" "$READELF"; do
  if [[ ! -x "$exe" ]]; then
    echo "error: missing executable tool: $exe" >&2
    exit 2
  fi
done

MAKE_BIN="${MAKE:-make}"
if [[ -z "${MAKE:-}" && "$(uname -s)" == "Darwin" ]] && command -v gmake >/dev/null 2>&1; then
  # musl Makefiles rely on GNU make functions such as $(file ...).
  MAKE_BIN="gmake"
fi
if ! command -v "$MAKE_BIN" >/dev/null 2>&1; then
  echo "error: make tool not found: $MAKE_BIN" >&2
  exit 2
fi
MAKE_LOG_RE='[[:alpha:]]*make: \*\*\* .*obj/[^ ]+.*Error'

CC_CMD="$CLANG --target=$TARGET -fuse-ld=lld"

build_runtime_builtins() {
  local -a srcs=(
    "adddf3.c"
    "subdf3.c"
    "muldf3.c"
    "divdf3.c"
    "addsf3.c"
    "subsf3.c"
    "mulsf3.c"
    "divsf3.c"
    "muldc3.c"
    "mulsc3.c"
    "atomic.c"
    "atomic_flag_clear.c"
    "atomic_flag_clear_explicit.c"
    "atomic_flag_test_and_set.c"
    "atomic_flag_test_and_set_explicit.c"
    "atomic_signal_fence.c"
    "atomic_thread_fence.c"
    "linx/fp_mode.c"
  )

  if [[ ! -d "$COMPILER_RT_BUILTINS_DIR" ]]; then
    echo "error: missing compiler-rt builtins directory: $COMPILER_RT_BUILTINS_DIR" >&2
    return 1
  fi

  rm -rf "$RUNTIME_DIR"
  mkdir -p "$RUNTIME_OBJ_DIR"
  : >"$RUNTIME_LOG"

  local -a objs=()
  local rel src obj
  for rel in "${srcs[@]}"; do
    src="$COMPILER_RT_BUILTINS_DIR/$rel"
    if [[ ! -f "$src" ]]; then
      echo "error: missing compiler-rt source: $src" >&2
      return 1
    fi

    obj="$RUNTIME_OBJ_DIR/${rel//\//_}.o"
    local extra_flag=""
    case "$rel" in
      atomic*|atomic/*)
        # Linx bring-up currently does not support i128 returns in the backend.
        # Keep 1/2/4/8-byte atomics enabled while suppressing 16-byte variants.
        extra_flag="-U__SIZEOF_INT128__"
        ;;
    esac

    if ! "$CLANG" \
      --target="$TARGET" \
      -O2 \
      -ffreestanding \
      -fno-builtin \
      -I"$COMPILER_RT_BUILTINS_DIR" \
      ${extra_flag:+$extra_flag} \
      -c "$src" \
      -o "$obj" >>"$RUNTIME_LOG" 2>&1; then
      echo "error: failed to compile compiler-rt source: $src (see $RUNTIME_LOG)" >&2
      return 1
    fi
    objs+=("$obj")
  done

  if ! "$AR" rc "$RUNTIME_LIB" "${objs[@]}" >>"$RUNTIME_LOG" 2>&1; then
    echo "error: failed to archive runtime builtins (see $RUNTIME_LOG)" >&2
    return 1
  fi
  if ! "$RANLIB" "$RUNTIME_LIB" >>"$RUNTIME_LOG" 2>&1; then
    echo "error: failed to ranlib runtime builtins (see $RUNTIME_LOG)" >&2
    return 1
  fi
}

install_runtime_builtins_to_sysroot() {
  local target_arch builtins_name
  target_arch="${TARGET%%-*}"
  builtins_name="libclang_rt.builtins-${target_arch}.a"

  mkdir -p "$INSTALL_DIR/lib" "$INSTALL_DIR/usr/lib"

  install -m 644 "$RUNTIME_LIB" "$INSTALL_DIR/lib/liblinx_builtin_rt.a"
  install -m 644 "$RUNTIME_LIB" "$INSTALL_DIR/usr/lib/liblinx_builtin_rt.a"
  install -m 644 "$RUNTIME_LIB" "$INSTALL_DIR/lib/$builtins_name"
  install -m 644 "$RUNTIME_LIB" "$INSTALL_DIR/usr/lib/$builtins_name"

  {
    echo "runtime_builtins_install=pass"
    echo "runtime_builtins_archive=$INSTALL_DIR/lib/liblinx_builtin_rt.a"
    echo "runtime_builtins_compat=$INSTALL_DIR/lib/$builtins_name"
  } >>"$SUMMARY"
}

build_phase_c_crt_fallback_objects() {
  if [[ "$MODE" != "phase-c" ]]; then
    return 0
  fi

  rm -rf "$PHASE_C_CRT_DIR"
  mkdir -p "$PHASE_C_CRT_DIR"

  cat >"$PHASE_C_CRT_DIR/crtbeginS.c" <<'EOF'
void *__dso_handle = &__dso_handle;
EOF
  cat >"$PHASE_C_CRT_DIR/crtendS.c" <<'EOF'
char __linx_crtend_anchor;
EOF

  "$CLANG" \
    --target="$TARGET" \
    -O2 \
    -fPIC \
    -ffreestanding \
    -fno-stack-protector \
    -fno-builtin \
    -c "$PHASE_C_CRT_DIR/crtbeginS.c" \
    -o "$PHASE_C_CRTBEGIN" >>"$RUNTIME_LOG" 2>&1

  "$CLANG" \
    --target="$TARGET" \
    -O2 \
    -fPIC \
    -ffreestanding \
    -fno-stack-protector \
    -fno-builtin \
    -c "$PHASE_C_CRT_DIR/crtendS.c" \
    -o "$PHASE_C_CRTEND" >>"$RUNTIME_LOG" 2>&1
}

install_phase_c_static_abi_pack() {
  if [[ "$MODE" != "phase-c" ]]; then
    return 0
  fi

  build_phase_c_crt_fallback_objects

  install -m 644 "$BUILD_DIR/lib/crt1.o" "$INSTALL_DIR/lib/Scrt1.o"
  install -m 644 "$BUILD_DIR/lib/crt1.o" "$INSTALL_DIR/usr/lib/Scrt1.o"
  install -m 644 "$PHASE_C_CRTBEGIN" "$INSTALL_DIR/lib/crtbeginS.o"
  install -m 644 "$PHASE_C_CRTEND" "$INSTALL_DIR/lib/crtendS.o"
  install -m 644 "$PHASE_C_CRTBEGIN" "$INSTALL_DIR/usr/lib/crtbeginS.o"
  install -m 644 "$PHASE_C_CRTEND" "$INSTALL_DIR/usr/lib/crtendS.o"

  local lib
  for lib in m pthread dl rt; do
    ln -sf libc.a "$INSTALL_DIR/lib/lib${lib}.a"
    ln -sf libc.a "$INSTALL_DIR/usr/lib/lib${lib}.a"
  done

  {
    echo "phase_c_static_abi_pack=pass"
    echo "phase_c_crtbegin=$INSTALL_DIR/lib/crtbeginS.o"
    echo "phase_c_crtend=$INSTALL_DIR/lib/crtendS.o"
  } >>"$SUMMARY"
}

install_phase_c_shared_abi_pack() {
  if [[ "$MODE" != "phase-c" ]]; then
    return 0
  fi

  local lib
  for lib in m pthread dl rt; do
    ln -sf libc.so "$INSTALL_DIR/lib/lib${lib}.so"
    ln -sf libc.so "$INSTALL_DIR/usr/lib/lib${lib}.so"
  done

  echo "phase_c_shared_abi_pack=pass" >>"$SUMMARY"
}

recover_phase_a_libc_symbols() {
  if [[ "$MODE" != "phase-a" ]]; then
    return 0
  fi

  local libc_archive="$BUILD_DIR/lib/libc.a"
  if [[ ! -f "$libc_archive" ]]; then
    return 0
  fi

  local need_vfscanf=1
  local need_tzname=1
  if "$NM" --defined-only "$libc_archive" | rg -q '\bvfscanf$'; then
    need_vfscanf=0
  fi
  if "$NM" --defined-only "$libc_archive" | rg -q '\b__tm_to_tzname$'; then
    need_tzname=0
  fi

  if (( need_vfscanf == 0 && need_tzname == 0 )); then
    return 0
  fi

  local rescue_dir="$RUNTIME_DIR/recover-libc"
  rm -rf "$rescue_dir"
  mkdir -p "$rescue_dir"

  local -a common_cflags=(
    --target="$TARGET"
    -fuse-ld=lld
    -std=c99
    -nostdinc
    -ffreestanding
    -fexcess-precision=standard
    -frounding-math
    -fno-strict-aliasing
    -Wa,--noexecstack
    -D_XOPEN_SOURCE=700
    -I"$MUSL_ROOT/arch/linx64"
    -I"$MUSL_ROOT/arch/generic"
    -I"$BUILD_DIR/obj/src/internal"
    -I"$MUSL_ROOT/src/include"
    -I"$MUSL_ROOT/src/internal"
    -I"$BUILD_DIR/obj/include"
    -I"$MUSL_ROOT/include"
    -O0
    -fno-align-functions
    -pipe
    -fomit-frame-pointer
    -fno-unwind-tables
    -fno-asynchronous-unwind-tables
    -ffunction-sections
    -fdata-sections
    -w
    -Wno-pointer-to-int-cast
    -Werror=implicit-function-declaration
    -Werror=implicit-int
    -Werror=pointer-sign
    -Werror=pointer-arith
    -Werror=int-conversion
    -Werror=incompatible-pointer-types
    -Qunused-arguments
    -Waddress
    -Warray-bounds
    -Wchar-subscripts
    -Wduplicate-decl-specifier
    -Winit-self
    -Wreturn-type
    -Wsequence-point
    -Wstrict-aliasing
    -Wunused-function
    -Wunused-label
    -Wunused-variable
    -fPIC
  )

  local -a rescue_objs=()
  if (( need_vfscanf == 1 )); then
    local vf_obj="$rescue_dir/vfscanf.o"
    "$CLANG" "${common_cflags[@]}" -c "$MUSL_ROOT/src/stdio/vfscanf.c" -o "$vf_obj" >>"$M2_LOG" 2>&1
    rescue_objs+=("$vf_obj")
  fi
  if (( need_tzname == 1 )); then
    local tz_obj="$rescue_dir/__tz.o"
    "$CLANG" "${common_cflags[@]}" -c "$MUSL_ROOT/src/time/__tz.c" -o "$tz_obj" >>"$M2_LOG" 2>&1
    rescue_objs+=("$tz_obj")
  fi

  if [[ ${#rescue_objs[@]} -gt 0 ]]; then
    "$AR" r "$libc_archive" "${rescue_objs[@]}" >>"$M2_LOG" 2>&1
    "$RANLIB" "$libc_archive" >>"$M2_LOG" 2>&1
    echo "phase_a_rescue_objs=${rescue_objs[*]}" >>"$SUMMARY"
  fi
}

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

{
  echo "mode=$MODE"
  echo "musl_root=$MUSL_ROOT"
  echo "target=$TARGET"
  echo "malloc_impl=$MALLOC_IMPL"
  echo "llvm_bin=$LLVM_BIN"
  echo "build_dir=$BUILD_DIR"
  echo "install_dir=$INSTALL_DIR"
  echo "runtime_builtins=$RUNTIME_LIB"
  echo "runtime_builtins_log=$RUNTIME_LOG"
  echo "make_bin=$MAKE_BIN"
  echo "jobs=$JOBS"
} > "$SUMMARY"

echo "[RT] build compiler-rt soft-float builtins"
if ! build_runtime_builtins; then
  {
    echo "m1=not-run"
    echo "m2=not-run"
    echo "m3=not-run"
  } >> "$SUMMARY"
  exit 1
fi

echo "[M1] configure ($MODE)"
if ! (
  cd "$BUILD_DIR"
  env \
    CC="$CC_CMD" \
    AR="$AR" \
    RANLIB="$RANLIB" \
    NM="$NM" \
    STRIP="$STRIP" \
    READELF="$READELF" \
    LIBCC="$RUNTIME_LIB" \
    "$MUSL_ROOT/configure" \
      --target="$TARGET" \
      --with-malloc="$MALLOC_IMPL" \
      --prefix=/usr \
      --syslibdir=/lib
) >"$CONFIG_LOG" 2>&1; then
  {
    echo "m1=fail"
    echo "m2=not-run"
    echo "m3=not-run"
  } >> "$SUMMARY"
  echo "error: M1 configure failed; see $CONFIG_LOG" >&2
  exit 1
fi
echo "m1=pass" >> "$SUMMARY"

echo "[M2] build static libc + crt objects ($MODE)"
PHASE_A_MAX_ROUNDS="${PHASE_A_MAX_ROUNDS:-16}"
phase_a_exclude_report="$LOG_DIR/${MODE}-exclusions.md"
extra_excludes=()
m2_ok=0
round=0
: >"$M2_LOG"

while true; do
  round=$((round + 1))
  {
    echo "== m2 round=$round mode=$MODE =="
    if [[ ${#extra_excludes[@]} -gt 0 ]]; then
      echo "extra_excludes=${extra_excludes[*]}"
    fi
  } >>"$M2_LOG"

  make_cmd=("$MAKE_BIN" -j"$JOBS" LINX_MUSL_MODE="$MODE")
  if [[ "$MODE" == "phase-a" && ${#extra_excludes[@]} -gt 0 ]]; then
    make_cmd+=("LINX_MUSL_EXTRA_EXCLUDES=${extra_excludes[*]}")
  fi
  make_cmd+=(lib/libc.a lib/crt1.o lib/crti.o lib/crtn.o)

  if (
    cd "$BUILD_DIR"
    "${make_cmd[@]}"
  ) >>"$M2_LOG" 2>&1; then
    m2_ok=1
    break
  fi

  if [[ "$MODE" != "phase-a" ]]; then
    break
  fi
  if (( round >= PHASE_A_MAX_ROUNDS )); then
    break
  fi

  failed_objs=()
  while IFS= read -r obj; do
    [[ "$obj" == obj/* ]] || continue
    failed_objs+=("$obj")
  done < <(
    rg "$MAKE_LOG_RE" "$M2_LOG" \
      | rg -o "obj/[^]]+" \
      | sed 's/\.lo$/.o/' \
      | sort -u
  )

  new_count=0
  for obj in ${failed_objs[@]+"${failed_objs[@]}"}; do
    if [[ -z "$obj" ]]; then
      continue
    fi

    skip=0
    if [[ ${#extra_excludes[@]} -gt 0 ]]; then
      for seen in ${extra_excludes[@]+"${extra_excludes[@]}"}; do
        if [[ "$obj" == "$seen" ]]; then
          skip=1
          break
        fi
      done
    fi
    if (( skip == 1 )); then
      continue
    fi

    extra_excludes+=("$obj")
    new_count=$((new_count + 1))
  done

  if (( new_count == 0 )); then
    break
  fi
done

if (( m2_ok == 0 )); then
  {
    echo "m2=fail"
    echo "m3=not-run"
  } >> "$SUMMARY"
  echo "error: M2 static build failed; see $M2_LOG" >&2
  exit 1
fi

if ! recover_phase_a_libc_symbols; then
  {
    echo "m2=fail"
    echo "m3=not-run"
  } >> "$SUMMARY"
  echo "error: phase-a libc symbol recovery failed; see $M2_LOG" >&2
  exit 1
fi

if [[ "$MODE" == "phase-a" && ${#extra_excludes[@]} -gt 0 ]]; then
  {
    echo "# Phase-A temporary excludes"
    echo
    echo "mode=$MODE"
    echo "issue_owner=llvm-backend"
    echo
    sig="$(rg -m1 'fatal error:|clang frontend command failed' "$M2_LOG" || true)"
    [[ -n "$sig" ]] && echo "crash_signature=$sig"
    echo
    echo "extra_excludes:"
    for obj in ${extra_excludes[@]+"${extra_excludes[@]}"}; do
      echo "- $obj"
    done
    echo
    echo "repro_files:"
    rg -o '/var/folders/[^ ]+\.(c|sh)' "$M2_LOG" | sort -u | sed 's/^/- /' || true
  } >"$phase_a_exclude_report"

  {
    echo "phase_a_extra_excludes_count=${#extra_excludes[@]}"
    echo "phase_a_extra_excludes=${extra_excludes[*]}"
    echo "phase_a_exclusion_report=$phase_a_exclude_report"
  } >>"$SUMMARY"
fi

(
  cd "$BUILD_DIR"
  "$MAKE_BIN" LINX_MUSL_MODE="$MODE" install-headers DESTDIR="$INSTALL_DIR"
) >>"$M2_LOG" 2>&1

mkdir -p "$INSTALL_DIR/lib" "$INSTALL_DIR/usr/lib"
install -m 644 "$BUILD_DIR/lib/libc.a" "$INSTALL_DIR/lib/libc.a"
install -m 644 "$BUILD_DIR/lib/libc.a" "$INSTALL_DIR/usr/lib/libc.a"
install -m 644 "$BUILD_DIR/lib/crt1.o" "$INSTALL_DIR/lib/crt1.o"
install -m 644 "$BUILD_DIR/lib/crti.o" "$INSTALL_DIR/lib/crti.o"
install -m 644 "$BUILD_DIR/lib/crtn.o" "$INSTALL_DIR/lib/crtn.o"
install -m 644 "$BUILD_DIR/lib/crt1.o" "$INSTALL_DIR/usr/lib/crt1.o"
install -m 644 "$BUILD_DIR/lib/crti.o" "$INSTALL_DIR/usr/lib/crti.o"
install -m 644 "$BUILD_DIR/lib/crtn.o" "$INSTALL_DIR/usr/lib/crtn.o"
install_runtime_builtins_to_sysroot
install_phase_c_static_abi_pack

echo "m2=pass" >> "$SUMMARY"

echo "[M3] attempt shared libc ($MODE)"
if (
  cd "$BUILD_DIR"
  "$MAKE_BIN" -j"$JOBS" LINX_MUSL_MODE="$MODE" lib/libc.so
) >"$M3_LOG" 2>&1; then
  install -m 755 "$BUILD_DIR/lib/libc.so" "$INSTALL_DIR/lib/libc.so"
  install -m 755 "$BUILD_DIR/lib/libc.so" "$INSTALL_DIR/usr/lib/libc.so"
  ln -sf libc.so "$INSTALL_DIR/lib/ld-musl-linx64.so.1"
  install_phase_c_shared_abi_pack
  echo "shared_install=pass" >>"$SUMMARY"
  echo "shared_lib=$INSTALL_DIR/lib/libc.so" >>"$SUMMARY"
  echo "shared_loader=$INSTALL_DIR/lib/ld-musl-linx64.so.1" >>"$SUMMARY"
  echo "m3=pass" >> "$SUMMARY"
  rm -f "$M3_BLOCKER_REPORT"
else
  fail_obj="$(rg -m1 "$MAKE_LOG_RE" "$M3_LOG" | rg -o "obj/[^]]+" || true)"
  fail_src=""
  if [[ -n "$fail_obj" ]]; then
    fail_src="$(rg -m1 " -c -o ${fail_obj//\//\\/} " "$M3_LOG" | sed -E 's/^.* -c -o [^ ]+ //g' || true)"
  fi
  crash_sig="$(rg -m1 'fatal error:|clang frontend command failed|error in backend' "$M3_LOG" || true)"
  if [[ -z "$crash_sig" ]]; then
    crash_sig="$(rg -m1 'error:' "$M3_LOG" || true)"
  fi
  {
    echo "# M3 blocker report"
    echo
    echo "mode=$MODE"
    echo "target=$TARGET"
    echo "malloc_impl=$MALLOC_IMPL"
    echo "issue_owner=llvm-backend"
    [[ -n "$fail_obj" ]] && echo "failing_object=$fail_obj"
    [[ -n "$fail_src" ]] && echo "failing_source=$fail_src"
    [[ -n "$crash_sig" ]] && echo "crash_signature=$crash_sig"
    echo
    echo "repro_files:"
    rg -o '/var/folders/[^ ]+\.(c|sh)' "$M3_LOG" | sort -u | sed 's/^/- /' || true
  } >"$M3_BLOCKER_REPORT"

  # Phase-B diagnostic probe:
  # Retry shared link with -z notext to surface the next blocker class once
  # read-only relocation policy is relaxed (typically unresolved builtins/stubs).
  if [[ "${M3_NOTEXT_PROBE:-1}" == "1" ]]; then
    if (
      cd "$BUILD_DIR"
      "$MAKE_BIN" -j"$JOBS" LINX_MUSL_MODE="$MODE" LDFLAGS="-Wl,-z,notext" lib/libc.so
    ) >"$M3_NOTEXT_LOG" 2>&1; then
      {
        echo
        echo "secondary_probe=notext"
        echo "secondary_status=pass"
      } >>"$M3_BLOCKER_REPORT"
      echo "m3_notext_probe=pass" >>"$SUMMARY"
      echo "m3_notext_probe_log=$M3_NOTEXT_LOG" >>"$SUMMARY"
    else
      probe_sig="$(rg -m1 'undefined (hidden )?symbol:|error:' "$M3_NOTEXT_LOG" || true)"
      {
        echo
        echo "secondary_probe=notext"
        echo "secondary_status=fail"
        [[ -n "$probe_sig" ]] && echo "secondary_signature=$probe_sig"
        echo "secondary_undefined_symbols:"
        rg -o 'undefined (hidden )?symbol: [^ ]+' "$M3_NOTEXT_LOG" \
          | sort -u \
          | sed 's/^/- /' \
          || true
      } >>"$M3_BLOCKER_REPORT"
      echo "m3_notext_probe=fail" >>"$SUMMARY"
      echo "m3_notext_probe_log=$M3_NOTEXT_LOG" >>"$SUMMARY"
      [[ -n "$probe_sig" ]] && echo "m3_notext_probe_signature=$probe_sig" >>"$SUMMARY"
    fi
  fi

  echo "m3=blocked" >> "$SUMMARY"
  echo "m3_blocker_report=$M3_BLOCKER_REPORT" >> "$SUMMARY"
  [[ -n "$fail_obj" ]] && echo "m3_failing_object=$fail_obj" >> "$SUMMARY"
  [[ -n "$crash_sig" ]] && echo "m3_crash_signature=$crash_sig" >> "$SUMMARY"
fi

update_latest_link() {
  local src="$1"
  local dst="$2"
  rm -f "$dst"
  ln -s "$src" "$dst"
}

update_latest_link "$(basename "$CONFIG_LOG")" "$LOG_DIR/${MODE}-configure.latest.log"
update_latest_link "$(basename "$M2_LOG")" "$LOG_DIR/${MODE}-m2-libc-a.latest.log"
update_latest_link "$(basename "$M3_LOG")" "$LOG_DIR/${MODE}-m3-shared.latest.log"
update_latest_link "$(basename "$SUMMARY")" "$LOG_DIR/${MODE}-summary.latest.txt"

echo "ok: $SUMMARY"
