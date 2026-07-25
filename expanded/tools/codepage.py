#!/usr/bin/env python3
"""GOLF code page — Jelly-style byte<->glyph mapping and (en/de)coder.

A GOLF program is a sequence of bytes, one byte per operation, drawn from the
full 0..255 space.  Like Jelly, the canonical form is raw bytes; humans read and
write them through a *code page* that shows each byte as a glyph.  Bytes 0..127
are ASCII (so ordinary GOLF text is already valid); bytes 0x80+ are single-byte
atoms shown as chosen glyphs (see tools/mkblob2.py, the source of truth).

Authoring is easiest in ASCII with backslash mnemonics — write `\\sqr`, `\\neg`,
… and `encode` turns them into the raw atom bytes.  Literal glyphs work too.

Usage:
  codepage.py encode <in.golfj >out.gb     # mnemonics/glyphs/ASCII -> raw bytes
  codepage.py decode <in.gb                 # raw bytes -> glyphs
  codepage.py decode -m <in.gb              # raw bytes -> ASCII \\mnemonic form
  codepage.py table                         # print the atom code-page reference
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mkblob2

# Prelude library words (see lib/prelude.golf).  These are ordinary single-byte
# word *calls* (ASCII letters), so their glyphs/mnemonics are input aliases only:
# encode maps ⍳/\range -> byte 'R'; decode shows the letter (a byte could be any
# user word).  (letter, mnemonic, glyph, doc)
LIB = [
    ("R", "range", "⍳", "range(n) -> [0..n-1]"),
    ("S", "sum",   "∑", "sum(list)"),
    ("L", "len",   "≢", "len(list)"),
    ("I", "index", "⊇", "index(list, i)"),
    ("A", "alloc", "⍶", "alloc(cells) -> addr"),
    ("N", "num",   "Ṅ", "print unsigned decimal"),
    ("E", "nl",    "␤", "print newline"),
    ("M", "map",   "€", "map(list, fn) -> list"),
    ("F", "fold",  "⇤", "fold(list, init, fn) -> x"),
    ("Q", "show",  "⍕", "print a list, space-separated"),
    ("P", "prod",  "∏", "product(list)"),
    ("V", "rev",   "⌽", "reverse(list) -> list"),
    ("W", "filter","⌿", "filter(list, pred) -> list (keep where pred==0)"),
]

# Compiler-level ops that are not atoms (handled specially in golf2's tokenizer).
# (byte, mnemonic, glyph, doc)
COMPILER = [
    (mkblob2.REF_BYTE, "ref", "′", "prefix: ′name pushes that word's address"),
]

# byte <-> glyph / mnemonic for the named atoms (ASCII bytes map to themselves)
BYTE2GLYPH = {b: gl for b, _mn, gl, _t, _d in mkblob2.ATOMS}
BYTE2MNEM  = {b: mn for b, mn, _gl, _t, _d in mkblob2.ATOMS}
GLYPH2BYTE = {gl: b for b, _mn, gl, _t, _d in mkblob2.ATOMS}
MNEM2BYTE  = {mn: b for b, mn, _gl, _t, _d in mkblob2.ATOMS}
# compiler ops: real single-byte tokens, shown on decode like atoms
BYTE2GLYPH.update({b: gl for b, _mn, gl, _d in COMPILER})
BYTE2MNEM.update({b: mn for b, mn, _gl, _d in COMPILER})
GLYPH2BYTE.update({gl: b for b, _mn, gl, _d in COMPILER})
MNEM2BYTE.update({mn: b for b, mn, _gl, _d in COMPILER})
# library aliases (encode-only: glyph/mnemonic -> the word's letter byte)
GLYPH2BYTE.update({gl: ord(ltr) for ltr, _mn, gl, _d in LIB})
MNEM2BYTE.update({mn: ord(ltr) for ltr, mn, _gl, _d in LIB})


def encode(text: str) -> bytes:
    """Turn glyph/mnemonic/ASCII source into raw code-page bytes."""
    out = bytearray()
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "#":                               # comment: dropped (source-only)
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "\\":                              # \name mnemonic escape
            if i + 1 < n and text[i + 1] == "\\":  # \\ -> literal backslash (swap)
                out.append(0x5C); i += 2; continue
            j = i + 1
            run = ""
            while j < n and text[j].isalpha():
                run += text[j]; j += 1
            k = len(run)                           # longest known-mnemonic prefix,
            while k > 0 and run[:k] not in MNEM2BYTE:  # so \sqr48 -> \sqr + 48 and
                k -= 1                             # \sqrp -> \sqr + word p
            if k == 0:
                raise SystemExit(f"codepage: unknown mnemonic \\{run}")
            out.append(MNEM2BYTE[run[:k]]); i = i + 1 + k
        elif c in GLYPH2BYTE:                       # a high-byte atom glyph
            out.append(GLYPH2BYTE[c]); i += 1
        elif ord(c) < 128:                          # plain ASCII byte (incl. WS)
            out.append(ord(c)); i += 1
        else:
            raise SystemExit(f"codepage: char {c!r} (U+{ord(c):04X}) is not in the code page")
    return bytes(out)


def decode(data: bytes, mnemonic: bool = False) -> str:
    out = []
    for b in data:
        if b in BYTE2GLYPH and b >= 0x80:
            out.append(f"\\{BYTE2MNEM[b]}" if mnemonic else BYTE2GLYPH[b])
        elif b in (9, 10) or 32 <= b < 127:
            out.append(chr(b))
        else:
            out.append(f"\\x{b:02X}")               # exact round-trip fallback
    return "".join(out)


def print_table():
    print("ATOMS (single-byte machine-code ops)")
    print("byte  glyph  mnemonic  meaning")
    for b, mn, gl, _t, doc in mkblob2.ATOMS:
        print(f"0x{b:02X}   {gl:>2}     \\{mn:<7}  {doc}")
    print("\nCOMPILER OPS (single-byte tokens handled by the compiler)")
    print("byte  glyph  mnemonic  meaning")
    for b, mn, gl, doc in COMPILER:
        print(f"0x{b:02X}   {gl:>2}     \\{mn:<7}  {doc}")
    print("\nLIBRARY (prelude words — glyph/mnemonic are input aliases for a letter)")
    print("byte  glyph  mnemonic  word  meaning")
    for ltr, mn, gl, doc in LIB:
        print(f"0x{ord(ltr):02X}   {gl:>2}     \\{mn:<7}  {ltr}     {doc}")


def main(argv):
    if len(argv) < 2 or argv[1] not in ("encode", "decode", "table"):
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "table":
        print_table(); return
    if cmd == "encode":
        sys.stdout.buffer.write(encode(sys.stdin.buffer.read().decode("utf-8")))
    else:
        mnem = "-m" in argv[2:]
        sys.stdout.write(decode(sys.stdin.buffer.read(), mnemonic=mnem))


if __name__ == "__main__":
    main(sys.argv)
