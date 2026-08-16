#!/usr/bin/env python3
"""Check Linx musl PTO ISA 0.58.1 identity wiring."""

from __future__ import annotations

import pathlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile


EXPECTED_DESCRIPTOR = (
    '{"encoding_abi":"pto-isa-0.58.1-mode-function-v1",'
    '"encoding_projection_sha256":'
    '"89b872d6eaf0252200bc9349d49b9346e2a69d894cdcc2dcd0fd71911c1e0b8c",'
    '"release":"0.58.1"}'
)

EXPECTED_RELOCS = {
    "R_LINX_TLS_DTPMOD64": 28,
    "R_LINX_TLS_DTPREL64": 29,
    "R_LINX_TLS_TPREL64": 30,
    "R_LINX_TLSDESC": 31,
    "R_LINX_IRELATIVE": 32,
}

NOTE_NAME = b"PTO\0"
NOTE_TYPE = 1
NOTE_SCAN_MAX = 4096


def align4(value: int) -> int:
    return (value + 3) & ~3


def make_note(name: bytes, note_type: int, desc: bytes) -> bytes:
    return (
        struct.pack("<III", len(name), len(desc), note_type)
        + name
        + b"\0" * (align4(len(name)) - len(name))
        + desc
        + b"\0" * (align4(len(desc)) - len(desc))
    )


def parse_fixture(payload: bytes) -> tuple[bool, bool]:
    if len(payload) > NOTE_SCAN_MAX:
        return False, True
    valid = False
    off = 0
    while off < len(payload):
        if len(payload) - off < 12:
            return False, True
        namesz, descsz, note_type = struct.unpack_from("<III", payload, off)
        name_off = off + 12
        desc_off = name_off + align4(namesz)
        next_off = desc_off + align4(descsz)
        if (
            next_off <= off
            or next_off > len(payload)
            or desc_off > len(payload)
            or descsz > len(payload) - desc_off
        ):
            return False, True
        name = payload[name_off:name_off + namesz]
        desc = payload[desc_off:desc_off + descsz]
        if namesz == len(NOTE_NAME) and note_type == NOTE_TYPE and name == NOTE_NAME:
            if desc != EXPECTED_DESCRIPTOR.encode():
                return False, True
            valid = True
        off = next_off
    return valid, False


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"error: {message}")


def read(repo: pathlib.Path, rel: str) -> str:
    return (repo / rel).read_text(encoding="utf-8")


def extract_c_string_macro(source: str, name: str) -> str:
    lines = source.splitlines()
    for index, line in enumerate(lines):
        if line.startswith(f"#define {name}"):
            macro_lines = [line]
            while macro_lines[-1].rstrip().endswith("\\"):
                index += 1
                require(index < len(lines), f"{name} continuation is open")
                macro_lines.append(lines[index])
            break
    else:
        raise SystemExit(f"error: {name} macro missing")
    parts = re.findall(r'"(?:\\.|[^"\\])*"', "\n".join(macro_lines))
    return "".join(bytes(part[1:-1], "utf-8").decode("unicode_escape")
                   for part in parts)


def check_fixtures() -> None:
    good = make_note(NOTE_NAME, NOTE_TYPE, EXPECTED_DESCRIPTOR.encode())
    mismatch = make_note(
        NOTE_NAME,
        NOTE_TYPE,
        b'{"encoding_abi":"pto-isa-0.58.0-mode-function-v1",'
        b'"encoding_projection_sha256":'
        b'"0cad2272ada8f53fc8354e22568099fe8d6bd4b7832c837260cd370b0fc76ffa",'
        b'"release":"0.58.0"}',
    )
    other = make_note(b"GNU\0", 3, b"build-id")
    cases = {
        "valid": (good, (True, False)),
        "missing": (other, (False, False)),
        "mismatch": (mismatch, (False, True)),
        "conflict": (good + mismatch, (False, True)),
        "duplicate-identical": (good + good, (True, False)),
        "malformed": (good + b"\1\2", (False, True)),
        "trailing-nul": (
            make_note(NOTE_NAME, NOTE_TYPE, EXPECTED_DESCRIPTOR.encode() + b"\0"),
            (False, True),
        ),
        "oversized": (good + b"x" * NOTE_SCAN_MAX, (False, True)),
    }
    for name, (payload, expected) in cases.items():
        actual = parse_fixture(payload)
        require(actual == expected,
                f"fixture {name} expected {expected}, got {actual}")


def run_c_harness(repo: pathlib.Path) -> None:
    cc = shutil.which("cc")
    require(cc is not None, "host C compiler 'cc' missing")
    source = repo / "tools/linx/pto_isa_identity_harness.c"
    with tempfile.TemporaryDirectory(prefix="pto-isa-identity-") as tmp:
        exe = pathlib.Path(tmp) / "pto_isa_identity_harness"
        subprocess.run(
            [cc, "-std=c11", "-Wall", "-Wextra", "-Werror", str(source), "-o", str(exe)],
            cwd=repo,
            check=True,
        )
        subprocess.run([str(exe)], cwd=repo, check=True)


def main() -> int:
    repo = pathlib.Path(__file__).resolve().parents[2]
    elf_h = read(repo, "include/elf.h")
    reloc_h = read(repo, "arch/linx64/reloc.h")
    dynlink = read(repo, "ldso/dynlink.c")
    identity_h = read(repo, "ldso/pto_isa_identity.h")
    configure = read(repo, "configure")
    build_script = read(repo, "tools/linx/build_linx64_musl.sh")

    require("#define ELF_NOTE_PTO" in elf_h, "ELF_NOTE_PTO missing")
    require("#define PTO_NT_ISA_IDENTITY\t1" in elf_h,
            "PTO_NT_ISA_IDENTITY must be 1")
    for name, expected in EXPECTED_RELOCS.items():
        match = re.search(rf"#define {name}\s+(\d+)", elf_h)
        require(match is not None, f"{name} missing")
        require(int(match.group(1)) == expected,
                f"{name} must be {expected}, found {match.group(1)}")
    for rel_macro in ("REL_DTPMOD", "REL_DTPOFF", "REL_TPOFF", "REL_TLSDESC"):
        require(rel_macro in reloc_h, f"{rel_macro} not routed through linx64")

    descriptor = extract_c_string_macro(dynlink, "PTO_ISA_IDENTITY_JSON")
    require(descriptor == EXPECTED_DESCRIPTOR,
            "PTO descriptor is not byte-exact")
    require("PTO_NOTE_SCAN_MAX 4096" in dynlink, "4KiB scan cap missing")
    require("pread(fd, buf, len, (off_t)off)" in dynlink,
            "fd PT_NOTE path must use positioned pread")
    require("PTO_ISA_OFFSET_MAX" in dynlink and "LLONG_MAX" in dynlink,
            "fd PT_NOTE path must bound unsigned p_offset to off_t")
    require("errno == EINTR" in identity_h and "done += l" in identity_h,
            "fd PT_NOTE path must handle EINTR and short reads")
    require("if (ph->p_align != 4) continue;" in identity_h,
            "unrelated non-4 PT_NOTE segments must be skipped, not rejected")
    require("pto_isa_note_range_loaded" in identity_h and "PT_LOAD" in identity_h,
            "mapped main path must validate PT_LOAD range")
    require("ph->p_filesz > ph->p_memsz" in identity_h,
            "mapped PT_NOTE path must reject p_filesz larger than p_memsz")
    require("map_addr(ctx, ph->p_vaddr)" in identity_h and "ph->p_filesz" in identity_h,
            "mapped PT_NOTE path must parse p_filesz, not p_memsz")
    require("pto_check_loaded_objects();" in dynlink,
            "startup closure check missing")
    require("pto_check_loaded_objects();\n\tif (ldso_fail) _exit(127);" in dynlink,
            "startup PTO rejection must fail before symbol export/relocation")
    require("pto_check_dependency_closure(p);" in dynlink,
            "dlopen closure check missing")
    require("linx64v5" not in configure and "linx64v4" not in configure,
            "legacy linx64v4/v5 configure targets still active")
    require("check_pto_isa_identity.py" in build_script,
            "build gate does not run PTO identity guard")

    check_fixtures()
    run_c_harness(repo)
    print("ok: Linx musl PTO ISA identity wiring matches 0.58.1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
