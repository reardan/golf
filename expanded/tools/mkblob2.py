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
    # Comparison / selection / signed arithmetic (result -1/0 like '<')
    (0x86, "gt",  "»", [0x59, 0x58, 0x48, 0x39, 0xC1, 0x48, 0x19, 0xC0, 0x50],
                                                          "a b -> (a>b unsigned ? -1 : 0)"),
    (0x87, "eq",  "≡", [0x59, 0x58, 0x48, 0x29, 0xC8, 0x48, 0x83, 0xE8, 0x01,
                        0x48, 0x19, 0xC0, 0x50],          "a b -> (a==b ? -1 : 0)"),
    (0x88, "max", "⌈", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x48, 0x0F, 0x42, 0xC1, 0x50],
                                                          "a b -> max(a,b) unsigned"),
    (0x89, "min", "⌊", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x48, 0x0F, 0x47, 0xC1, 0x50],
                                                          "a b -> min(a,b) unsigned"),
    (0x8A, "sdv", "÷", [0x59, 0x58, 0x48, 0x99, 0x48, 0xF7, 0xF9, 0x50],
                                                          "a b -> a/b signed"),
    (0x8B, "smd", "∣", [0x59, 0x58, 0x48, 0x99, 0x48, 0xF7, 0xF9, 0x52],
                                                          "a b -> a%b signed"),
    # Quotations: exec is an indirect call (pop a word address, call it).  Its
    # partner `ref` (push a word's address) is a compiler prefix, added to `t`
    # below — together they give higher-order functions (map/fold).
    (0x8D, "exec", "⍎", [0x58, 0xFF, 0xD0],               "pop a word address, call it"),
]

# `ref` (byte 0x8C, glyph ′): a compiler *prefix* — read the next byte (a word
# name) and emit `push <that word's runtime address>` instead of a call.  This
# is the first change to golf2's compiler logic vs v1.  Written in pure v1 GOLF
# so v1 still compiles golf2.golf; golf2's own source never uses it, so the
# strict fixpoint (stage1 == stage2) still holds.
REF_BYTE = 0x8C
# ′name pushes name's address.  If name is a defined word, push its VA.  If it is
# an ATOM (a template in the blob, not a word), emit a thunk [prologue][template]
# [epilogue] inline (jumped over) and push the thunk's VA — so ′+ works without
# wrapping.  Compiler scratch m20 (jmp-site), m24 (thunk addr).
REF_CASE = ('"140-[_("m2048+\\4*+@"[_233o m4+@m20+!0w m4+@m24+! 1E"E94E '
            'm4+@m20+@4+-m20+@!104o m24+@69632-w_^]\\_69632-104o w^]')
# Insert the case into `t` just before its `e;` fallthrough.  `w^]e;` is the
# unique junction between t's last case (the blob handler) and `e;` (t only
# occurrence of `e;`; other words follow t in WORDS).
# `str` (byte 0x8E, glyph “): a compiler op for string literals.  “...” emits a
# length-prefixed byte block [len(4)][bytes] (jumped over) and pushes its
# address.  A string is thus a byte block; `chars` converts it to a list of
# codes so all list ops apply.  Compiler scratch: m20 jmp-site, m24 len-site,
# m12 push-VA, m28 count.  Pure v1 GOLF; golf2's own source never uses it.
STR_BYTE = 0x8E
STR_CASE = ('"142-[_233o m4+@m20+!0w m4+@m24+! m4+@69632-m12+!0w 0 m28+!'
            '{("142-[_m28+@m24+@!m4+@m20+@4+-m20+@!104o m12+@w^]o m28+@1+m28+!0}]')

# Named variables: →x stores TOS to a name-indexed cell, ←x loads it.  Compiler
# prefixes (bytes 0x8F/0x90): read the name byte and emit an absolute 32-bit
# store/load to a per-program variable bank at 0x4E0000 (bank[name] = +4*name).
# NOTE: these are GLOBAL (one cell per name), not per-call frame — recursion
# does not get fresh copies.  Frame-based locals remain a later step.
SET_BYTE = 0x8F   # →   store: pop rax; mov [0x4E0000+4*name], eax
GET_BYTE = 0x90   # ←   load:  mov eax,[0x4E0000+4*name]; push rax
SET_CASE = '"143-[_(4*5111808+88o 137o 4o 37o w^]'
GET_CASE = '"144-[_(4*5111808+139o 4o 37o w 80o^]'

assert mkblob.WORDS.count("w^]e;") == 1, "anchor not unique"
WORDS2 = mkblob.WORDS.replace(
    "w^]e;", "w^]" + REF_CASE + STR_CASE + SET_CASE + GET_CASE + "e;")

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
    parts = [code(WORDS2), code(mkblob.INIT),
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
