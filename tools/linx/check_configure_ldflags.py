#!/usr/bin/env python3
"""Check that configure linker probes preserve required base LDFLAGS."""

from __future__ import annotations

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
REQUIRED = "-Wl,--linx-required-probe-flag"


def parse_assignment(config: str, name: str) -> list[str]:
    prefix = f"{name} = "
    for line in config.splitlines():
        if line.startswith(prefix):
            return shlex.split(line[len(prefix) :])
    raise AssertionError(f"missing {name} assignment")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="linx-musl-configure-") as tmp:
        tmpdir = Path(tmp)
        log = tmpdir / "cc.log"
        wrapper = tmpdir / "cc-wrapper"
        wrapper.write_text(
            """#!/bin/sh
set -eu
: "${REAL_CC:?}"
: "${CC_LOG:?}"
printf '%s\\n' "$*" >> "$CC_LOG"
is_link=0
seen_required=0
for arg do
    test "$arg" = "-shared" && is_link=1
    test "$arg" = "-Wl,--linx-required-probe-flag" && seen_required=1
done
if test "$is_link" = 1 && test "$seen_required" = 0; then
    exit 1
fi
if test "$is_link" = 1; then
    exit 0
fi
for arg do
    case "$arg" in
        *.c) grep -q LDBL_MANT_DIG "$arg" 2>/dev/null && exit 0 ;;
    esac
done
exec "$REAL_CC" "$@"
""",
            encoding="utf-8",
        )
        wrapper.chmod(0o755)

        env = os.environ.copy()
        env.update(
            {
                "CC": str(wrapper),
                "CC_LOG": str(log),
                "REAL_CC": shutil.which("cc") or "cc",
                "LDFLAGS": REQUIRED,
            }
        )
        proc = subprocess.run(
            [str(ROOT / "configure"), "--target=x86_64-linux-musl"],
            cwd=tmpdir,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        if proc.returncode:
            raise AssertionError(f"configure failed:\n{proc.stdout}")

        config = (tmpdir / "config.mak").read_text(encoding="utf-8")
        ldflags = parse_assignment(config, "LDFLAGS")
        auto = parse_assignment(config, "LDFLAGS_AUTO")
        assert ldflags.count(REQUIRED) == 1, ldflags
        assert "-Wl,--gc-sections" in auto, auto
        assert any(flag.startswith("-Wl,--dynamic-list=") for flag in auto), auto

        probe = next(
            line
            for line in log.read_text(encoding="utf-8").splitlines()
            if "-shared" in line and "--gc-sections" in line
        )
        args = shlex.split(probe)
        assert args.count(REQUIRED) == 1, args
        assert args.index(REQUIRED) < args.index("-Wl,--gc-sections"), args

    print("configure linker probes preserve base LDFLAGS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
