#!/usr/bin/env python3
"""Assemble expanded/self/golf2.golf — the seed of the expanded GOLF compiler.

Bootstrap strategy: the v2 compiler is written in **minimal GOLF (v1)** and is
compiled by the v1 toolchain (../minimal). So golf2.golf's *code* is, for now,
byte-identical to v1's self-hosted compiler; only the embedded template table
grows. New "dumb" operators cost nothing but a template — the compiler's `e`
word already dispatches any op it finds in the blob — so this file adds them by
extending v1's template set. Structural features (multi-char names, locals,
...) come in later milestones and will change the code, at which point golf2
migrates to using those features and self-hosts. See ../DESIGN.md.
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "minimal", "boot"))
sys.path.insert(0, os.path.join(HERE, "..", "..", "minimal", "tools"))
import golf0    # v1 templates / header (single source of truth)
import mkblob   # v1 code sections + golf() rewrites + blob helpers

# --- Milestone 1: new operators. Pure machine-code templates, no logic change.
# v1 had used every free single-char slot except these five; adding them
# exhausts the printable-ASCII op space — which is exactly what motivates
# multi-char identifiers in Milestone 2 (see ../DESIGN.md).
NEW_OPS = {
    '~': [0x58, 0x48, 0xF7, 0xD0, 0x50],        # bitwise NOT  pop rax; not rax; push
    '$': [0x58, 0x48, 0x21, 0x04, 0x24],        # bitwise AND  pop rax; and [rsp],rax
    '|': [0x58, 0x48, 0x09, 0x04, 0x24],        # bitwise OR   pop rax; or  [rsp],rax
    '=': [0x58, 0x48, 0x31, 0x04, 0x24],        # bitwise XOR  pop rax; xor [rsp],rax
    '>': [0x59, 0x48, 0xD3, 0x2C, 0x24],        # shift right  pop rcx; shr [rsp],cl
}

def templates2():
    t = dict(golf0.TEMPLATES)
    t.update(NEW_OPS)
    return t

def build_blob2():
    b = bytearray()
    b += mkblob.rec(1, golf0.PROLOGUE)
    b += mkblob.rec(2, mkblob.COND)
    b += mkblob.rec(3, golf0.STARTUP)
    b += mkblob.rec(4, mkblob.header_pairs())
    b += mkblob.rec(5, golf0.AUTOEXIT)
    for ch, tpl in templates2().items():
        b += mkblob.rec(ord(ch), tpl)
    b += bytes([0])
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
                     f"(blob {len(build_blob2())}, +{len(NEW_OPS)} new ops)\n")

if __name__ == "__main__":
    main()
