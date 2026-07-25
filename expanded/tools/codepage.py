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
  codepage.py check                         # assert the namespace invariants
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mkblob2

# Prelude library words (see lib/prelude.golf).  (key, mnemonic, glyph, doc)
# The key is the byte the word is called by, in one of two forms:
#   * a 1-char ASCII letter — an ordinary letter-named word.  Encode-only: ⍳ and
#     \range both map to byte 'R', but decode shows the plain letter, since a
#     low byte could equally be a *user* word of the same name.
#   * an int byte >= 0x80 — a word living in the high-byte word range (see
#     ../REGISTRY.md §1, 0xC0-0xCF).  Unambiguous, so it decodes like an atom.
# Byte/mnemonic/glyph allocations come from ../REGISTRY.md; `codepage.py check`
# enforces them.
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
    ("O", "puts",  "🗲", "print a “...” byte string"),
    ("U", "chars", "⊃", "byte string -> list of char codes"),
    ("J", "join",  "⊐", "print a code list as text (cell -> byte)"),
    ("Z", "zip",   "⊞", "zip(l1, l2, fn) -> list (elementwise)"),
    # --- W2 LIB rows ---
    # M-TAG shape-polymorphic operators (REGISTRY.md §1.2).  High-byte prelude
    # words: 0xC0-0xC4 are word *names*, not atoms — no mkblob2 template — but
    # being >= 0x80 they decode as well as encode.
    (0xC0, "vadd", "∔", "polymorphic add (int/list, elementwise, broadcast)"),
    (0xC1, "vsub", "∸", "polymorphic sub (int/list, elementwise, broadcast)"),
    (0xC2, "vmul", "⨰", "polymorphic mul (int/list, elementwise, broadcast)"),
    (0xC3, "vmin", "⩍", "polymorphic min (int/list, elementwise, broadcast)"),
    (0xC4, "vmax", "⩌", "polymorphic max (int/list, elementwise, broadcast)"),
]

# Compiler-level ops that are not atoms (handled specially in golf2's tokenizer).
# (byte, mnemonic, glyph, doc)
COMPILER = [
    (mkblob2.REF_BYTE, "ref", "′", "prefix: ′name pushes that word's address"),
    (mkblob2.STR_BYTE, "str", "“", "string literal delimiter: “text“ -> byte block"),
    (mkblob2.SET_BYTE, "set", "→", "prefix: →x pops TOS into variable x"),
    (mkblob2.GET_BYTE, "get", "←", "prefix: ←x pushes variable x"),
]

def lib_byte(key) -> int:
    """The call byte of a LIB row: an int byte, or a 1-char ASCII letter."""
    if isinstance(key, int):
        return key
    assert len(key) == 1 and ord(key) < 128, f"bad LIB key {key!r}"
    return ord(key)


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
# library words: glyph/mnemonic -> the word's call byte, always.  A high-byte
# word additionally decodes (nothing else can own that byte); a letter word does
# not (that byte may be any user word), so it stays encode-only as before.
for _key, _mn, _gl, _doc in LIB:
    _b = lib_byte(_key)
    GLYPH2BYTE[_gl] = _b
    MNEM2BYTE[_mn] = _b
    if _b >= 0x80:
        BYTE2GLYPH[_b] = _gl
        BYTE2MNEM[_b] = _mn


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
    print("\nLIBRARY (prelude words — a letter word's glyph/mnemonic are input aliases)")
    print("byte  glyph  mnemonic  word  meaning")
    for key, mn, gl, doc in LIB:
        b = lib_byte(key)
        word = key if isinstance(key, str) else "-"     # high-byte words: no letter
        print(f"0x{b:02X}   {gl:>2}     \\{mn:<7}  {word}     {doc}")


def all_rows():
    """Every allocated op byte, as (byte, mnemonic, glyph, table-name)."""
    rows  = [(b, mn, gl, "ATOMS")    for b, mn, gl, _t, _d in mkblob2.ATOMS]
    rows += [(b, mn, gl, "COMPILER") for b, mn, gl, _d in COMPILER]
    rows += [(lib_byte(k), mn, gl, "LIB") for k, mn, gl, _d in LIB]
    return rows


def check():
    """Enforce the three namespace invariants of ../REGISTRY.md.

    Silent + exit 0 on success; a report on stderr + exit 1 on any violation.
    """
    rows, errs = all_rows(), []

    seen = {}                                   # (a) one owner per op byte
    for b, mn, gl, where in rows:
        if b in seen:
            omn, owhere = seen[b]
            errs.append(f"byte 0x{b:02X} allocated twice: "
                        f"{owhere} \\{omn} and {where} \\{mn}")
        seen[b] = (mn, where)

    # (b) the encoder takes the LONGEST KNOWN MNEMONIC PREFIX of the alpha run
    # after a `\`, so a mnemonic that is a proper prefix of another silently
    # changes how existing sources parse.  No prefix pairs, ever.
    for i, (_b, mn, _gl, where) in enumerate(rows):
        for _b2, mn2, _gl2, where2 in rows[i + 1:]:
            if mn == mn2:
                errs.append(f"mnemonic \\{mn} defined twice ({where}, {where2})")
            elif mn2.startswith(mn):
                errs.append(f"mnemonic \\{mn} ({where}) is a proper prefix of "
                            f"\\{mn2} ({where2}) — the encoder would mis-split it")
            elif mn.startswith(mn2):
                errs.append(f"mnemonic \\{mn2} ({where2}) is a proper prefix of "
                            f"\\{mn} ({where}) — the encoder would mis-split it")

    glyphs = {}                                 # (c) one meaning per glyph
    for b, mn, gl, where in rows:
        if gl in glyphs:
            omn, owhere = glyphs[gl]
            errs.append(f"glyph {gl} used twice: {owhere} \\{omn} and {where} \\{mn}")
        glyphs[gl] = (mn, where)

    for b, mn, gl, where in rows:               # (d) high bytes are decodable
        if b >= 0x80 and BYTE2GLYPH.get(b) != gl:
            errs.append(f"byte 0x{b:02X} ({where} \\{mn}) has no glyph in "
                        f"BYTE2GLYPH — decode could not round-trip it")

    if errs:
        sys.stderr.write("codepage: REGISTRY.md invariants violated\n")
        for e in errs:
            sys.stderr.write(f"  - {e}\n")
        sys.exit(1)


def main(argv):
    if len(argv) < 2 or argv[1] not in ("encode", "decode", "table", "check"):
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "table":
        print_table(); return
    if cmd == "check":
        check(); return
    if cmd == "encode":
        sys.stdout.buffer.write(encode(sys.stdin.buffer.read().decode("utf-8")))
    else:
        mnem = "-m" in argv[2:]
        sys.stdout.write(decode(sys.stdin.buffer.read(), mnemonic=mnem))


if __name__ == "__main__":
    main(sys.argv)
