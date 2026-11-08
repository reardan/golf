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
  codepage.py reference                     # the same tables as Markdown (REFERENCE.md)
  codepage.py reference --update FILE       # splice them between FILE's markers
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
    ("N", "num",   "Ṅ", "print signed decimal"),
    ("E", "nl",    "␤", "print newline"),
    ("M", "map",   "€", "map(list, fn) -> list"),
    ("F", "fold",  "⇤", "fold(list, init, fn) -> x"),
    ("Q", "show",  "⍕", "print a list, space-separated; inner lists as [a b]"),
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
    (0xC3, "vmin", "⩍", "polymorphic signed min (int/list, elementwise, broadcast)"),
    (0xC4, "vmax", "⩌", "polymorphic signed max (int/list, elementwise, broadcast)"),
    (0xC5, "comp", "∘", "compose: ′f ′g -> ′(x -> g(f x))"),
    (0xC6, "pipe", "⇉", "pipeline: x qlist -> y (apply each quotation in turn)"),
    (0xC7, "fork", "⑂", "fork: x ′f ′g ′h -> h(f x, g x)"),
    (0xC8, "match", "≣", "match: a b -> -1/0, structural equality into nested lists"),
    (0xC9, "depth", "⍤", "depth: int 0, flat list 1, list of lists 2, ..."),
    # --- W9-4A LIB rows: list words (prelude anchor W9-4A-LISTWORDS1) ---
    (0xCB, "cat",  "⧺", "concatenate: l1 l2 -> new list (l1 then l2)"),
    (0xCC, "take", "↑", "take: list n -> first n (n<0: last |n|; clamped to len)"),
    (0xCD, "drop", "↓", "drop: list n -> all but first n (n<0: all but last |n|)"),
    # --- W9-3C LIB row ---
    (0xCA, "free", "⌫", "free(list|block): release an A block to the free list"),
    # --- W9-4B LIB rows: list words (prelude anchor W9-4B-LISTWORDS2) ---
    (0xCE, "sort", "⍋", "sort: list -> new list, ascending signed (stable merge sort)"),
    (0xCF, "memb", "∊", "member: list x -> 0 if x is an element, else 1"),
    # --- W11-2C LIB row: closures by value (prelude anchor W11-2C bind) ---
    (0xD0, "bind", "⊸", "bind: x ′f -> ′g; g pushes the captured x, then calls f"),
    # --- W12-A2 / W12-A3 LIB rows (prelude sections W12-A2, W12-A3) ---
    (0xD1, "scan", "⍀", "scan: l ′f -> l'; inclusive, l'[0] = l[0], l'[i] = f(l'[i-1], l[i])"),
    (0xD2, "reduce", "⍁", "reduce: l ′f -> x; fold seeded by l[0] (empty: empty reduce)"),
    (0xD3, "eachi", "⍸", "each-indexed: l ′f -> l'; l'[i] = f(l[i], i)"),
    # --- W12-A4 LIB row: sort by key (prelude section W12-A4) ---
    (0xD4, "ksort", "⍒", "sort by key: l ′k -> l'; stable, ascending by k x (k once per element)"),
    # --- W12-Z4 LIB rows: store-at, vector push/pop (prelude section W12-Z4) ---
    (0xD5, "putat", "⍈", "store-at: list i v -> list; list[i] = v in place (bounds-checked)"),
    (0xD6, "push", "⍆", "push: v x -> v'; append x (vector or deque back); use the returned v'"),
    (0xD7, "pop",  "⍅", "pop: v -> v x; remove the last element (empty: pop from empty)"),
    # --- W12-A5 / W12-A6 LIB rows (prelude sections W12-A5, W12-A6) ---
    (0xD8, "win",  "⊟", "window reduce: l n ′f -> f-reduce of every length-n window (deque for ⌈ ⌊)"),
    (0xD9, "fix",  "⍣", "fixpoint: x ′f -> y; apply f until the result ≣ the previous one"),
    # --- W12-A8 LIB row: the stream protocol (prelude section W12-A8) ---
    (0xDA, "next", "⍞", "stream next: s -> s x 0 | s 1 (zero-is-true, like ‹readline›)"),
    # --- W12-Z1 LIB rows: one-byte aliases of the hottest long names (prelude
    # section W12-Z1).  Each byte is a one-call word that runs the long name,
    # which stays.  Mnemonics are letters only and prefix-free: \dget \dput
    # because \get (←) is a compiler op and \puts / \putat exist.
    (0xDB, "ints", "ℤ", "alias of ‹ints›: -> list, all of stdin as integers"),
    (0xDC, "readall", "⎕", "alias of ‹readall›: -> list, the rest of stdin as a code list"),
    (0xDD, "readline", "⏎", "alias of ‹readline›: -> list flag, the next line without its \\n (flag 0), 1 at end"),
    (0xDE, "dict", "Ḋ", "alias of ‹dict›: -> d, a new empty dict"),
    (0xDF, "dget", "Ġ", "alias of ‹get›: d k -> v (missing: key not found)"),
    (0xE0, "dput", "Ṗ", "alias of ‹put›: d k v -> d"),
    (0xE1, "keys", "Ḳ", "alias of ‹keys›: d -> list, the keys in insertion order"),
    (0xE2, "bump", "Ḃ", "alias of ‹bump›: d k -> d, add 1 to k's value (missing: 1)"),
    (0xE3, "vec", "Ṿ", "alias of ‹vec›: -> v, a new empty vector"),
    # --- W13-C LIB rows: list words for LeetCode-style programs (prelude
    # section W13-C).  Mnemonics are letters only and prefix-free: \lookup
    # (not \dgetor, which \dget is a prefix of) and \tfword (\tf is the word).
    (0xE4, "lmax", "Ṁ", "max of list: l -> x, signed (empty: empty reduce)"),
    (0xE5, "lmin", "Ṃ", "min of list: l -> x, signed (empty: empty reduce)"),
    (0xE6, "uncons", "⍘", "uncons: l -> tail head (empty: empty list)"),
    (0xE7, "rscan", "⍂", "right scan: l ′f -> l'; exactly ⌽ ′f⍀ ⌽ (f gets acc x)"),
    (0xE8, "xscan", "⍃", "exclusive scan: l s ′f -> l'; l'[0] = s, l'[i] = f(l'[i-1], l[i-1]), ≢l' = ≢l"),
    (0xE9, "counter", "Ċ", "counter: l -> d; element -> count, keys in first-seen order"),
    (0xEA, "dsort", "⍖", "sort by key, descending: l ′k -> l'; stable (ties keep input order)"),
    (0xEB, "prevocc", "Ṕ", "previous occurrence: l -> l'; l'[i] = last j < i with l[j] = l[i], else -1"),
    (0xEC, "findfirst", "⍷", "find first: l ′p -> i; first i where p l[i] is 0 (stops there), else -1"),
    (0xED, "indices", "ℑ", "indices: l -> l [0..n-1] (keeps l)"),
    (0xEE, "lookup", "Ǧ", "alias of ‹getor›: d k x -> v, k's value or x when absent"),
    (0xEF, "tfword", "ṭ", "alias of ‹tf›: f -> list, “true“ when f is 0, else “false“"),
]

# Compiler-level ops that are not atoms (handled specially in golf2's tokenizer).
# (byte, mnemonic, glyph, doc)
COMPILER = [
    (mkblob2.REF_BYTE, "ref", "′", "prefix: ′name pushes that word's address"),
    (mkblob2.STR_BYTE, "str", "“", "string literal delimiter: “text“ -> byte block"),
    (mkblob2.SET_BYTE, "set", "→", "prefix: →x pops TOS into variable x"),
    (mkblob2.GET_BYTE, "get", "←", "prefix: ←x pushes variable x"),
    (mkblob2.CHAIN_BYTE, "chain", "⊚",
     "prefix: ⊚name f g h; defines a tacit chain (a train of links)"),
    (mkblob2.FRAME_BYTE, "dloc", "⊡",
     "prefix: ⊡name ... ; defines a word with a frame of per-call locals, one cell each"),
    (mkblob2.LSET_BYTE, "lset", "⇒", "prefix: ⇒x pops TOS into local x (a..z or ‹name›)"),
    (mkblob2.LGET_BYTE, "lget", "⇐", "prefix: ⇐x pushes local x (a..z or ‹name›)"),
    (mkblob2.LNAME_BYTE, "lname", "‹",
     "opens a long name: ‹name› stands wherever a one-byte name can"),
    (mkblob2.RNAME_BYTE, "rname", "›", "closes a long name"),
    (mkblob2.IMPORT_BYTE, "import", "⎘",
     "prefix: ⎘“path“ compiles that file in place (once; searches . then lib/ then vendor/)"),
    (mkblob2.REC_BYTE, "rec", "⊜",
     "prefix: ⊜‹point›‹x›‹y›; defines ‹point› (x y -> rec), ‹point-x› (rec -> x), ‹set-point-x› (rec v -> rec)"),
    (mkblob2.ELSE_BYTE, "else", "⋄",
     "separator: c[a⋄b] runs a when c is 0, else b; {c⋄body} tests c before each pass, runs body while it is 0"),
    (mkblob2.VINC_BYTE, "vinc", "⇡",
     "prefix: ⇡x adds 1 to variable x in place (←x⊕→x; in a ⊡ word, a local already named there)"),
    (mkblob2.VDEC_BYTE, "vdec", "⇣",
     "prefix: ⇣x subtracts 1 from variable x in place (←x⊖→x; in a ⊡ word, a local already named there)"),
    # --- W13-A: S2 inline blocks ---
    (mkblob2.BLOCK_BYTE, "blk", "⟦",
     "opens an inline block: ⟦ … ⟧ is an anonymous word compiled in place; ⟧ pushes its address"),
    (mkblob2.ENDBLOCK_BYTE, "endblk", "⟧", "closes an inline block and pushes its address"),
    # W13-B (S6): the digraph prefix.  ʘ + any byte B is the long name ‹_dgHH›.
    (mkblob2.DIGRAPH_BYTE, "dig", "ʘ",
     "prefix: ʘB (any byte B) is the long name ‹_dgHH›, HH = B in upper-case hex (see Digraph page)"),
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


# String literals (../REGISTRY.md "W9", shipped by W9-1B).  Between two
# delimiters the source is LITERAL: its UTF-8 is copied verbatim — no mnemonics,
# no glyph encoding, `#` is not a comment.  Either spelling of the delimiter
# opens a literal, and either closes it: the glyph `“` or the exact text `\str`.
# The one escape is `\“`, which stands for the UTF-8 bytes of `“` (E2 80 9C).
# Consequences: the text `\str` cannot appear inside a literal (it closes it),
# and neither can any character whose UTF-8 holds byte 0x8E — the compiler
# copies bytes up to the next 0x8E — so such a literal is an encode error.
STR_GLYPH = "“"
STR_MNEM = "\\str"
STR_ESC = "\\“"
STR_ESC_BYTES = STR_GLYPH.encode("utf-8")      # E2 80 9C
STR_ERR = "codepage: a string literal cannot contain byte 0x8E (the string delimiter)"


def _delim(text: str, i: int) -> int:
    """Length of the string delimiter starting at text[i], or 0."""
    if text[i] == STR_GLYPH:
        return 1
    return len(STR_MNEM) if text.startswith(STR_MNEM, i) else 0


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
        d = _delim(text, i)
        if d:                                      # a string literal: verbatim
            out.append(mkblob2.STR_BYTE); i += d
            while i < n:
                if text.startswith(STR_ESC, i):    # \“ -> the bytes of “
                    out += STR_ESC_BYTES; i += len(STR_ESC); continue
                d = _delim(text, i)
                if d:                              # the closing delimiter
                    out.append(mkblob2.STR_BYTE); i += d
                    break
                b = text[i].encode("utf-8")
                if mkblob2.STR_BYTE in b:
                    raise SystemExit(STR_ERR)
                out += b; i += 1
            continue                               # (an unclosed literal runs to EOF)
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
    """Raw bytes -> glyph (or `-m` mnemonic) source.

    Byte 0x8E toggles "inside a literal".  Inside one, bytes are copied RAW (as
    surrogate-escaped str, so even invalid UTF-8 survives to stdout byte for
    byte), except E2 80 9C, which is written as the escape `\\“`.  The closer is
    `“`, or `\\str` when the literal's last byte is a backslash (`\\“` would read
    back as the escape).  This is a byte-level rule on purpose: gtools/decode
    applies the same one without a UTF-8 decoder.
    """
    out = []
    in_str = False
    i, n = 0, len(data)
    while i < n:
        b = data[i]
        if b == mkblob2.STR_BYTE:
            if mnemonic:
                out.append(STR_MNEM)
            elif in_str and data[i - 1] == 0x5C:
                out.append(STR_MNEM)
            else:
                out.append(STR_GLYPH)
            in_str = not in_str; i += 1
        elif in_str:
            if data[i:i + 3] == STR_ESC_BYTES:
                out.append(STR_ESC); i += 3
            else:
                out.append(bytes([b]).decode("utf-8", "surrogateescape")); i += 1
        else:
            if b in BYTE2GLYPH and b >= 0x80:
                out.append(f"\\{BYTE2MNEM[b]}" if mnemonic else BYTE2GLYPH[b])
            elif b in (9, 10) or 32 <= b < 127:
                out.append(chr(b))
            else:
                out.append(f"\\x{b:02X}")           # exact round-trip fallback
            i += 1
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


# REFERENCE.md carries the output of `reference` between these two lines, and
# run2.sh (W9-1D) requires it to equal the current output, so the generated half
# of the language reference cannot drift from the tables above.
REF_BEGIN = "<!-- BEGIN GENERATED: python3 tools/codepage.py reference -->"
REF_END = "<!-- END GENERATED -->"


def _md(text) -> str:
    """One Markdown table cell: a pipe would end the cell, even in a code span."""
    return str(text).replace("|", "\\|")


def reference_md() -> str:
    """The v2 atom / compiler-op / library tables, as Markdown."""
    out = []
    w = out.append
    w("### Atoms\n")
    w("Single-byte machine-code ops (`tools/mkblob2.py` `ATOMS`): "
      "the compiler copies each one's template inline.\n")
    w("| byte | glyph | mnemonic | meaning |")
    w("|---|---|---|---|")
    for b, mn, gl, _t, doc in mkblob2.ATOMS:
        w(f"| `0x{b:02X}` | `{_md(gl)}` | `\\{mn}` | {_md(doc)} |")
    w("\n### Compiler ops\n")
    w("Single-byte tokens the compiler handles itself (prefixes, delimiters, "
      "definition headers) — there is no template behind them.\n")
    w("| byte | glyph | mnemonic | meaning |")
    w("|---|---|---|---|")
    for b, mn, gl, doc in COMPILER:
        w(f"| `0x{b:02X}` | `{_md(gl)}` | `\\{mn}` | {_md(doc)} |")
    w("\n### Library words\n")
    w("Words defined by the prelude (`lib/prelude.golfj`). A letter word is "
      "called by its ASCII letter; its glyph and mnemonic are input aliases for "
      "that letter. A high-byte word has no letter.\n")
    w("| byte | glyph | mnemonic | word | meaning |")
    w("|---|---|---|---|---|")
    for key, mn, gl, doc in LIB:
        b = lib_byte(key)
        word = f"`{key}`" if isinstance(key, str) else "—"
        w(f"| `0x{b:02X}` | `{_md(gl)}` | `\\{mn}` | {word} | {_md(doc)} |")
    # W13-B (S6): the digraph page, scanned from the prelude.
    w("\n### Digraph page\n")
    w("Two-byte words: `ʘ` (`\\dig`, `0xBD`) then any byte B compiles as a call "
      "to the long name `‹_dgHH›` (HH = B in upper-case hex). The prelude gives "
      "a word a digraph with `:‹_dgHH›‹name›;`. Generated from "
      "`lib/prelude.golfj`.\n")
    w("| digraph | bytes | long name | word | meaning |")
    w("|---|---|---|---|---|")
    rows = digraphs()
    for b, target, comment in rows:
        w(f"| `{_md(digraph_glyph(b))}` | `BD {b:02X}` | `‹{DIGRAPH_PREFIX}{b:02X}›` "
          f"| `{_md(target)}` | {_md(comment)} |")
    if not rows:
        w("| — | | | | none defined yet |")
    return "\n".join(out) + "\n"


# W13-B (S6): the digraph page.  Generated from lib/prelude.golfj: every line
# that defines `:‹_dgHH›…` is a digraph ʘ + byte 0xHH.  A body that is just
# one long-name call (`:‹_dgHH›‹name›;`) shows that name as the target; any
# other body shows `(own body)`.  The comment on the line, if any, is the
# meaning column.
PRELUDE = os.path.join(HERE, "..", "lib", "prelude.golfj")
DIGRAPH_PREFIX = "_dg"


def digraphs(path=PRELUDE):
    """[(byte, target, comment)] for each `:‹_dgHH›` definition, by byte."""
    import re
    rows = {}
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().split("\n")
    except OSError:
        return []
    pat = re.compile(r"^\s*:‹" + DIGRAPH_PREFIX + r"([0-9A-F]{2})›(.*)$")
    for line in lines:
        m = pat.match(line)
        if not m:
            continue
        b, rest = int(m.group(1), 16), m.group(2)
        code, _, comment = rest.partition("#")
        t = re.fullmatch(r"\s*‹([0-9A-Za-z_-]+)›\s*;\s*", code)
        target = f"‹{t.group(1)}›" if t else "(own body)"
        rows[b] = (b, target, comment.strip())
    return [rows[b] for b in sorted(rows)]


def digraph_glyph(b) -> str:
    """ʘ + byte b as written in .golfj: b's glyph, or the ASCII byte itself."""
    if b >= 0x80 and b in BYTE2GLYPH:
        return "ʘ" + BYTE2GLYPH[b]
    return "ʘ" + (chr(b) if 32 < b < 127 else f"\\x{b:02X}")


def reference_splice(path):
    """Rewrite the generated block of `path` in place (between the markers)."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    a, z = text.find(REF_BEGIN), text.find(REF_END)
    if a < 0 or z < a:
        raise SystemExit(f"codepage: {path} lacks the reference markers")
    a += len(REF_BEGIN)
    new = text[:a] + "\n" + reference_md() + text[z:]
    with open(path, "w", encoding="utf-8") as f:
        f.write(new)


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
    if len(argv) < 2 or argv[1] not in ("encode", "decode", "table", "check",
                                        "reference"):
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "table":
        print_table(); return
    if cmd == "reference":
        if argv[2:3] == ["--update"] and len(argv) == 4:
            reference_splice(argv[3])
        elif len(argv) == 2:
            sys.stdout.write(reference_md())
        else:
            sys.exit(__doc__)
        return
    if cmd == "check":
        check(); return
    if cmd == "encode":
        sys.stdout.buffer.write(encode(sys.stdin.buffer.read().decode("utf-8")))
    else:
        mnem = "-m" in argv[2:]
        sys.stdout.buffer.write(decode(sys.stdin.buffer.read(), mnemonic=mnem)
                                .encode("utf-8", "surrogateescape"))


if __name__ == "__main__":
    main(sys.argv)
