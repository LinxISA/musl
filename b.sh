#!/bin/bash

if [ "x$1" == "xv4" ]; then
    TOOLCHAIN_DIR="/home/ll/d/mshare/share/repos/linx/2025/binaries/linx_blockisa_llvm_musl_043"
    TARGET="linx64v4-linux-musl"
    MCPU="v0.43g"
    EXTRA_OPT=""
    HOST="linx64v4-linux-musl"
fi

if [ "x$1" == "xv5" ]; then
    TOOLCHAIN_DIR="/home/ll/d/mshare/share/repos/linx/2025/binaries/linx_blockisa_llvm_musl_050"
    TARGET="linx64v5-linux-musl"
    MCPU="v0.43g"
    EXTRA_OPT="-mllvm -linxv5-enable-finstr=false"
    HOST="linx64v5-linux-musl"
fi

if [ "x$TOOLCHAIN_DIR" == "x" ]; then
    echo "$0 [v4|v5]"
    exit
fi

UNWIND_HEADER_DIR="/home/ll/d/mshare/share/repos/linx/2025/linx-BLK-build/src/linx-llvm/libunwind/include"

CC_OPT="-fno-short-enums -fno-short-wchar -O2 --target=$TARGET -mcpu=$MCPU -mlittle-endian  -Wall -fstack-protector-strong  -I$UNWIND_HEADER_DIR -D_FORTIFY_SOURCE=2 -fPIE -DLINX_USE_JEMALLOC $EXTRA_OPT"

./configure \
    --build=x86_64-linux-gnu \
    --host=$HOST \
    --disable-shared \
    --enable-static \
    --enable-backtrace \
    --prefix=$TOOLCHAIN_DIR \
    --libdir=$TOOLCHAIN_DIR/sysroot/usr/lib \
    --includedir=$TOOLCHAIN_DIR/sysroot/usr/include \
    CC="$TOOLCHAIN_DIR/bin/clang $CC_OPT" \
    AR="$TOOLCHAIN_DIR/bin/llvm-ar" \
    RANLIB="$TOOLCHAIN_DIR/bin/llvm-ranlib" \
    CC_FOR_TARGET=$TOOLCHAIN_DIR/bin/clang \
    CXX_FOR_TARGET=$TOOLCHAIN_DIR/bin/clang++ \
    AR_FOR_TARGET=$TOOLCHAIN_DIR/bin/llvm-ar \
    AS_FOR_TARGET=$TOOLCHAIN_DIR/bin/clang \
    NM_FOR_TARGET=$TOOLCHAIN_DIR/bin/llvm-nm \
    READELF_FOR_TARGET= \
    RANLIB_FOR_TARGET=$TOOLCHAIN_DIR/bin/llvm-ranlib \
    LDFLAGS="-z relro -z now -z noexecstack -Wl,-Bsymbolic -Wl,-s -rdynamic -Wl,--no-undefined" \
    CFLAGS_FOR_TARGET="$CC_OPT" \
    CXXFLAGS_FOR_TARGET="$CC_OPT"

echo
echo
echo "======= configuration finished ========"

echo "TOOCHAINDIR: $TOOLCHAIN_DIR"
echo "TAGET: $TARGET"
echo "MCPU: $MCPU"
echo "CC_OPT: $CC_OPT"

echo "======= ====== ======= ======= ========"

