#!/usr/bin/env python3
"""Assemble expanded/self/golf2.golf — the seed of the expanded GOLF compiler.

Bootstrap strategy: the v2 compiler is written in **minimal GOLF (v1)** and is
compiled by the v1 toolchain (../minimal). golf2.golf's *code* is, for now,
byte-identical to v1's self-hosted compiler; only the embedded template table
grows. New "dumb" operators cost nothing but a template — the compiler's `e`
word already dispatches ANY byte it finds in the blob, including bytes 128-255 —
so this file adds them by extending v1's template set. See ../DESIGN.md.

The move toward a Jelly-style code page: operators are single bytes drawn from
the full 0..255 space, each shown via a code page glyph (../tools/codepage.py).
This module is the single source of truth for the atoms: their byte, glyph,
mnemonic, and machine-code template.
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "minimal", "boot"))
sys.path.insert(0, os.path.join(HERE, "..", "..", "minimal", "tools"))
import golf0    # v1 templates / header (single source of truth for v1 ops)
import mkblob   # v1 code sections + golf() rewrites + blob helpers

# --- Atoms added on top of the minimal v1 op set.  Each is a pure machine-code
#     template (no compiler-logic change).  (byte, mnemonic, glyph, template, doc)
#     M1 atoms live at printable-ASCII bytes; the code-page atoms live at 0x80+.
ATOMS = [
    # Milestone 1 — bitwise/shift, at the last free printable-ASCII bytes
    (0x7E, "not", "~", [0x58, 0x48, 0xF7, 0xD0, 0x50],        "bitwise NOT"),
    (0x24, "and", "$", [0x58, 0x48, 0x21, 0x04, 0x24],        "bitwise AND"),
    (0x7C, "or",  "|", [0x58, 0x48, 0x09, 0x04, 0x24],        "bitwise OR"),
    (0x3D, "xor", "=", [0x58, 0x48, 0x31, 0x04, 0x24],        "bitwise XOR"),
    (0x3E, "shr", ">", [0x59, 0x48, 0xD3, 0x2C, 0x24],        "shift right (by TOS)"),
    # Code-page atoms — single-byte ops in the high half of the byte space
    (0x80, "neg", "±", [0x58, 0x48, 0xF7, 0xD8, 0x50],   "negate TOS"),
    (0x81, "inc", "⊕", [0x48, 0xFF, 0x04, 0x24],         "TOS + 1"),
    (0x82, "dec", "⊖", [0x48, 0xFF, 0x0C, 0x24],         "TOS - 1"),
    (0x83, "sqr", "²", [0x58, 0x48, 0x0F, 0xAF, 0xC0, 0x50], "TOS * TOS"),
    (0x84, "dbl", "⊗", [0x48, 0xD1, 0x24, 0x24],         "TOS * 2"),
    (0x85, "hlv", "⊘", [0x48, 0xD1, 0x2C, 0x24],         "TOS >> 1"),
]

def build_blob2():
    b = bytearray()
    b += mkblob.rec(1, golf0.PROLOGUE)
    b += mkblob.rec(2, mkblob.COND)
    b += mkblob.rec(3, golf0.STARTUP)
    b += mkblob.rec(4, mkblob.header_pairs())
    b += mkblob.rec(5, golf0.AUTOEXIT)
    for ch, tpl in golf0.TEMPLATES.items():          # v1 op templates
        b += mkblob.rec(ord(ch), tpl)
    for byte, _mn, _gl, tpl, _doc in ATOMS:          # v2 atom templates
        b += mkblob.rec(byte, tpl)
    b += bytes([0])                                  # sentinel
    return bytes(b)

def build_source2():
    blob = build_blob2()
    code = lambda s: mkblob.golf(s.replace(" ", "")).encode()
    parts = [code(mkblob.WORDS), code(mkblob.INIT),
             b"`" + str(len(blob)).encode() + b" " + blob,
             code(mkblob.TAIL)]
    return b"".join(parts)

def main():
    src = build_source2()
    out = os.path.join(HERE, "..", "self", "golf2.golf")
    with open(out, "wb") as f:
        f.write(src)
    sys.stderr.write(f"wrote {out}: {len(src)} bytes "
                     f"(blob {len(build_blob2())}, {len(ATOMS)} atoms)\n")

if __name__ == "__main__":
    main()
