#!/usr/bin/env python3
"""The frozen v1 substrate, read from ../data/v1.hex.

v2 is grown from v1: its template blob starts as v1's op templates and v1's ELF
header, and only then adds atoms and overrides (tools/mkblob2.py).  So the v1
tables are a build INPUT here, and this module is where they enter.

They used to enter as `import golf0` out of the minimal tree next door.  That
tree now lives on its own branch (`minimal`, tag v1.0-minimal) and the compiler
built from it arrives as a pinned release binary (../SEEDS, tools/seed.sh), so
the tables arrive as data instead: ../data/v1.hex, one [key][len][data] record
per line, exactly the blob `minimal/tools/mkblob.py` builds.

Everything golf0.py exposed is recoverable from those records, and this module
does that reconstruction:

    PROLOGUE COND STARTUP AUTOEXIT   records 1, 2, 3, 5
    HEADER                           record 4, the non-zero (offset, value)
                                     pairs written over 120 zero bytes
    TEMPLATES                        every record after 5, keyed by its op byte
    EPILOGUE                         TEMPLATES['^'] — v1's `^` IS the epilogue
    BASE FILESZ                      p_vaddr and p_filesz, read out of HEADER

Nothing here is a policy decision and nothing here may drift: v1 is frozen, so
data/v1.hex is frozen, and .github/workflows/release-minimal.yml re-derives it
from the `minimal` branch and fails the release if the bytes differ.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
V1_HEX = os.path.join(HERE, "..", "data", "v1.hex")

# Fixed record keys, as allocated by minimal/tools/mkblob.py.
K_PROLOGUE, K_COND, K_STARTUP, K_HEADER, K_AUTOEXIT = 1, 2, 3, 4, 5

HEADER_LEN = 120                    # Ehdr (64) + one Phdr (56)
PHOFF = 64                          # the Phdr sits right after the Ehdr
VADDR_OFF = PHOFF + 16              # p_type, p_flags, p_offset, then p_vaddr
FILESZ_OFF = PHOFF + 32             # ... p_paddr, then p_filesz


def _records(path=V1_HEX):
    """[(key, bytes), ...] in file order.  `#` lines are comments; the file
    holds no terminating sentinel (see its header), so neither does this."""
    out = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            b = bytes(int(x, 16) for x in line.split())
            key, ln, data = b[0], b[1], b[2:]
            assert ln == len(data), f"v1.hex: record {key} claims {ln}, has {len(data)}"
            out.append((key, data))
    return out


_RECS = _records()
_FIXED = {key: data for key, data in _RECS if key <= K_AUTOEXIT}

PROLOGUE = _FIXED[K_PROLOGUE]
COND = _FIXED[K_COND]               # shared prefix of the '[' and '}' templates
STARTUP = _FIXED[K_STARTUP]
AUTOEXIT = _FIXED[K_AUTOEXIT]


def _header():
    """Record 4 is the header's non-zero bytes as (offset, value) pairs — the
    output buffer is BSS, so the zeros are never stored.  Undo that."""
    pairs = _FIXED[K_HEADER]
    hdr = bytearray(HEADER_LEN)
    for off, val in zip(pairs[0::2], pairs[1::2]):
        hdr[off] = val
    return bytes(hdr)


HEADER = _header()
assert len(HEADER) == HEADER_LEN and HEADER[:4] == b"\x7fELF", "v1.hex: not an ELF header"

BASE = int.from_bytes(HEADER[VADDR_OFF:VADDR_OFF + 8], "little")     # 0x400000
FILESZ = int.from_bytes(HEADER[FILESZ_OFF:FILESZ_OFF + 8], "little")  # 0x10000

# Op templates, keyed by op char, in blob order — build_blob2() re-emits them in
# this order and the compiler's record lookup returns the FIRST match for a key.
TEMPLATES = {chr(key): list(data) for key, data in _RECS if key > K_AUTOEXIT}
EPILOGUE = bytes(TEMPLATES["^"])    # v1's early-return op IS the word epilogue


def rec(key, data):
    """One blob record: [key][len][len bytes]."""
    assert 1 <= len(data) <= 255, (key, len(data))
    return bytes([key, len(data)]) + bytes(data)


def build_blob():
    """v1's blob, exactly as minimal/tools/mkblob.py builds it (sentinel and
    all).  Not on the build path — v2 embeds build_blob2() — but it is what
    data/v1.hex spells out, so it is what the release workflow diffs against."""
    return b"".join(rec(k, d) for k, d in _RECS) + bytes([0])


if __name__ == "__main__":
    import sys
    sys.stdout.buffer.write(build_blob())
