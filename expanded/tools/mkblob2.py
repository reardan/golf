#!/usr/bin/env python3
"""Assemble the two generated compiler sources in expanded/self/ (M-SELF).

Both are built here, and both embed the **identical** template blob from
`build_blob2()`.  They differ only in the language the compiler's *logic* is
written in:

    self/seed.golf    compiler logic in **v1 GOLF** — hand-written in
                      `self/seed.golfv1`, comments stripped by `build_seed()`
                      with the blob spliced in at its `@BLOB@` marker.  This is
                      the bootstrap rung: v1c (the pinned frozen v1 compiler,
                      ../SEEDS) can compile it, and that is its only job — to
                      produce a compiler able to build golf2.golf.

    self/golf2.golf   compiler logic in **v2 GOLF** — hand-written in
                      `self/golf2.golfj` (named variables, one op per line, the
                      language the compiler grew), code-page encoded by
                      `build_golf2()` with the blob spliced in at its `@BLOB@`
                      marker.  This is the compiler proper, and the one the
                      ladder converges on: golf2 compiles golf2.golf back to
                      itself, byte for byte.

Since M-SELF, compiler logic is authored in `self/golf2.golfj`.  `seed.golfv1`
exists only to bootstrap it out of v1 and is frozen in shape: it is not where
new compiler features go.  Both OUTPUTS are generated — never hand-edit
`self/seed.golf` or `self/golf2.golf`; edit the two sources next to them, run
`python3 tools/mkblob2.py` from `expanded/`, and commit the result.  (That one
command also rewrites data/codepage.tsv and data/blob.hex, through
tools/mktables.py.)

v1 itself is no longer a source tree here.  Its op templates and ELF header
arrive as data — `data/v1.hex`, read by `boot/v1.py` — and the compiler built
from it arrives as a pinned release binary (`../SEEDS`, `tools/seed.sh`).  The
tree they came from is frozen on the `minimal` branch.

W14-L: the tables are SOURCE DATA.  Every op byte's mnemonic, glyph and doc is
a row of `data/ops.tsv`, and every byte of the template blob is spelled out in
`data/templates.txt`, in a small notation (hex bytes, named fragments with
arguments, labels and jumps) documented at the top of that file.  This module
READS both — ATOMS, OVERRIDES, STARTUP2, AUTOEXIT2, ADVERBS, UNQUOTED and the
compiler-op bytes are all loaded from them — and keeps the module API the rest
of the repo imports.  What stays here is the memory map: the addresses and
sizes the templates and both compilers are laid out around, each of which is
checked against the bytes the data file actually holds.  The GOLF tool
gtools/tables.golfj reads the same two files and must build the same blob
(test/gtools.sh).

New "dumb" operators still cost nothing but a template — the compiler's `e` word
dispatches ANY byte it finds in the blob, including bytes 128-255 — so adding
one means an `A` row in data/ops.tsv and a `tpl` line in data/templates.txt.
See ../DESIGN.md and ../REGISTRY.md §4.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "boot"))
import v1       # the frozen v1 substrate: templates, ELF header, blob helpers

DATA = os.path.join(HERE, "..", "data")
OPS_TSV = os.path.join(DATA, "ops.tsv")
TEMPLATES_TXT = os.path.join(DATA, "templates.txt")


# --- data/ops.tsv: the code page --------------------------------------------
def read_ops(path=OPS_TSV):
    """[(table, byte, mnemonic, glyph, doc)] in file order (format: its header).

    Only the SHAPE is checked here — five fields, a known table letter, a
    two-digit hex byte, a letters-only mnemonic, one glyph character.  The
    namespace rules (one owner per byte, prefix-free mnemonics, one meaning per
    glyph) are `codepage.py check`'s, which reports every violation at once.
    """
    rows = []
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f.read().split("\n"), 1):
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            def bad(why):
                raise SystemExit(f"{os.path.relpath(path)}:{n}: {why}")
            if len(fields) != 5:
                bad(f"expected 5 TAB-separated fields, found {len(fields)}")
            table, byte, mn, gl, doc = fields
            if table not in ("A", "C", "L"):
                bad(f"table must be A, C or L, not '{table}'")
            if not re.fullmatch(r"[0-9A-F]{2}", byte):
                bad(f"byte must be two uppercase hex digits, not '{byte}'")
            if not re.fullmatch(r"[A-Za-z]+", mn):
                bad(f"mnemonic must be ASCII letters, not '{mn}'")
            if len(gl) != 1:
                bad(f"glyph must be one character, not '{gl}'")
            rows.append((table, int(byte, 16), mn, gl, doc))
    return rows

OPS = read_ops()


# --- data/templates.txt: the template blob ------------------------------------
_IDENT = r"[A-Za-z_][A-Za-z0-9_]*"
_KEYWORDS = ("def", "rec", "tpl", "override", "v1ops", "atoms")
_V1_RECS = dict(v1._RECS)          # data/v1.hex, key -> bytes (op char or 1..5)


class Templates:
    """data/templates.txt, parsed; `call()` expands a fragment to a byte list.

    The notation is documented at the top of that file.  Expansion is
    by value: an argument is expanded where the call is, and a fragment's
    labels are resolved inside each expansion, so one fragment can be used any
    number of times.  Every error names the file and the statement's line.
    """

    def __init__(self, path=TEMPLATES_TXT):
        self.path = path
        self.defs = {}         # name -> (params, tokens, line)
        self.stmts = []        # (kind, key, tokens, line) for rec/v1ops/atoms
        self.tpl = {}          # byte -> (tokens, line)
        self.over = {}         # byte -> (tokens, line), in file order
        with open(path, encoding="utf-8") as f:
            text = f.read()
        cur = None
        for n, raw in enumerate(text.split("\n"), 1):
            line = raw.split("#", 1)[0]
            toks = line.split()
            if not toks:
                continue
            if raw[0] in " \t":
                if cur is None:
                    self._die(n, "an indented line with no statement above it")
                cur[2].extend(toks)
                continue
            cur = self._statement(n, toks)

    def _die(self, line, why):
        raise SystemExit(f"{os.path.relpath(self.path)}:{line}: {why}")

    def _byte(self, line, tok):
        if not re.fullmatch(r"[0-9A-Fa-f]{2}", tok):
            self._die(line, f"expected a two-digit hex byte, not '{tok}'")
        return int(tok, 16)

    def _statement(self, n, toks):
        kw, args = toks[0], toks[1:]
        if kw not in _KEYWORDS:
            self._die(n, f"unknown statement '{kw}'")
        if kw in ("v1ops", "atoms"):
            if args:
                self._die(n, f"{kw} takes nothing")
            self.stmts.append((kw, None, [], n))
            return None
        if not args:
            self._die(n, f"{kw} needs a {'name' if kw == 'def' else 'byte'}")
        if kw == "def":
            name, params = args[0], args[1:]
            for x in [name] + params:
                if not re.fullmatch(_IDENT, x):
                    self._die(n, f"bad fragment or parameter name '{x}'")
            if name in self.defs:
                self._die(n, f"fragment {name} defined twice")
            st = [kw, name, [], n]
            self.defs[name] = (params, st[2], n)
            return st
        key = self._byte(n, args[0])
        st = [kw, key, list(args[1:]), n]
        if kw == "rec":
            self.stmts.append(("rec", key, st[2], n))
        else:
            table = self.tpl if kw == "tpl" else self.over
            if key in table:
                self._die(n, f"{kw} {key:02X} given twice")
            table[key] = (st[2], n)
        return st

    # -- expansion ----------------------------------------------------------
    def body(self, toks, env, line, depth=0):
        """Expand a token list: bytes, with every label jump filled in."""
        if depth > 32:
            self._die(line, "fragments nest more than 32 deep (a cycle?)")
        out, labels, jumps = [], {}, []
        for t in toks:
            if t.endswith(":") and re.fullmatch(_IDENT, t[:-1]):
                if t[:-1] in labels:
                    self._die(line, f"label {t[:-1]} defined twice in one body")
                labels[t[:-1]] = len(out)
            elif t.startswith(">"):
                n = 4 if t.startswith(">>") else 1
                lab = t[n if n == 1 else 2:]
                if not re.fullmatch(_IDENT, lab):
                    self._die(line, f"bad jump '{t}'")
                jumps.append((len(out), n, lab))
                out += [0] * n
            else:
                out += self.token(t, env, line, depth)
        for pos, n, lab in jumps:
            if lab not in labels:
                self._die(line, f"jump to undefined label {lab}")
            d = labels[lab] - (pos + n)
            if n == 1 and not -128 <= d <= 127:
                self._die(line, f"jump to {lab} is {d} bytes, out of rel8 range")
            out[pos:pos + n] = list((d % (1 << 8 * n)).to_bytes(n, "little"))
        return out

    def token(self, t, env, line, depth=0):
        """One non-label token -> its bytes."""
        if re.fullmatch(r"[0-9A-Fa-f]{2}", t):
            return [int(t, 16)]
        m = re.fullmatch(r"w:([0-9A-Fa-f]{1,8})", t)
        if m:
            return list(int(m.group(1), 16).to_bytes(4, "little"))
        if t.startswith("$"):
            if t[1:] not in env:
                self._die(line, f"{t} is not a parameter here")
            return list(env[t[1:]])
        m = re.fullmatch(r"v1:([0-9A-Fa-f]{2})(?:\+([0-9]+))?", t)
        if m:
            key = int(m.group(1), 16)
            if key not in _V1_RECS:
                self._die(line, f"data/v1.hex has no record {key:02X}")
            return list(_V1_RECS[key][int(m.group(2) or 0):])
        m = re.fullmatch(r"atom:([0-9A-Fa-f]{2})", t)
        if m:
            key = int(m.group(1), 16)
            if key not in self.tpl:
                self._die(line, f"no `tpl {key:02X}`")
            toks, tline = self.tpl[key]
            return self.body(toks, {}, tline, depth + 1)
        m = re.fullmatch(r"len:(" + _IDENT + ")", t)
        if m:
            n = len(self.call(m.group(1), [], line, depth + 1))
            if n > 255:
                self._die(line, f"len:{m.group(1)} is {n}, more than a byte")
            return [n]
        m = re.fullmatch(r"(" + _IDENT + r")(?:\(([^()]*)\))?", t)
        if m:
            args = m.group(2).split(",") if m.group(2) is not None else []
            vals = [self.token(a, env, line, depth + 1) for a in args]
            return self.call(m.group(1), vals, line, depth + 1)
        self._die(line, f"cannot read token '{t}'")

    def call(self, name, args=(), line=0, depth=0):
        """Fragment `name` with its parameters bound to the byte lists `args`."""
        if name not in self.defs:
            self._die(line, f"no fragment named {name}")
        params, toks, dline = self.defs[name]
        if len(args) != len(params):
            self._die(line, f"{name} takes {len(params)} argument(s), "
                            f"given {len(args)}")
        return self.body(toks, dict(zip(params, args)), dline, depth)

    def records(self):
        """The `rec` records, key -> bytes."""
        return {k: bytes(self.body(t, {}, n)) for kind, k, t, n in self.stmts
                if kind == "rec"}


TPL = Templates()
_u32 = lambda v: list(v.to_bytes(4, "little"))
_u16 = lambda v: list(v.to_bytes(2, "little"))
_RECORDS = TPL.records()

# --- the atoms: data/ops.tsv's A rows, with data/templates.txt's `tpl`s -------
# (byte, mnemonic, glyph, template, doc).  M1 atoms live at printable-ASCII
# bytes; the code-page atoms live at 0x80+.
def _atoms():
    out, seen = [], set()
    for table, b, mn, gl, doc in OPS:
        if table != "A":
            continue
        if b not in TPL.tpl:
            raise SystemExit(f"data/ops.tsv: atom {b:02X} \\{mn} has no "
                             f"`tpl {b:02X}` in data/templates.txt")
        toks, n = TPL.tpl[b]
        out.append((b, mn, gl, TPL.body(toks, {}, n), doc))
        seen.add(b)
    for b, (_t, n) in TPL.tpl.items():
        if b not in seen:
            TPL._die(n, f"tpl {b:02X} is not an atom (no A row in data/ops.tsv)")
    return out
ATOMS = _atoms()
_ATOM_TPL = {b: tpl for b, _mn, _gl, tpl, _d in ATOMS}

# byte -> replacement template.  build_blob2 emits the override INSTEAD of the
# original record (the compiler's `f` returns the FIRST record for a key, so
# emitting both would be a silent no-op); boot/golfref.py applies the same dict
# LAST over its TEMPLATES (dict update = last wins), so the two agree.
OVERRIDES = {b: TPL.body(t, {}, n) for b, (t, n) in TPL.over.items()}

# --- the hook calls (data/templates.txt `def hookcall`) -----------------------
# Every hook is a runtime cell (../REGISTRY.md §3) that the prelude's init fills
# with a word's address; BSS 0 without the prelude, so a compiler binary runs a
# load, a test and a not-taken jump.
FLUSH_HOOK = 0x4F0990      # W11-1C: ‹flush›, before every exit and raw I/O
DIV0_HOOK = 0x4F0B10       # W11-3A: ‹_3a_div0›, makes ÷ ∣ / % catchable
END_HOOK = 0x4F09A0        # W13-B: ‹_13b_end›, implicit output at program end
NAN_HOOK = 0x4F0DC0        # W12-O1: ‹_12o1_nan›, ± ⊕ ⊖ ² ⊗ ⊘ refuse a list
def _hook_call(cell):
    """`call [cell]` when the cell is non-zero: 15 bytes, absolute, rax only."""
    return TPL.call("hookcall", [_u32(cell)])
_FLUSH_CALL = TPL.call("flush")
_DIV0_CALL = TPL.call("div0hook")
_END_CALL = TPL.call("endhook")
_NAN_CALL = TPL.call("nanhook")
assert len(_FLUSH_CALL) == 15
for _cell, _call in ((FLUSH_HOOK, _FLUSH_CALL), (DIV0_HOOK, _DIV0_CALL),
                     (END_HOOK, _END_CALL), (NAN_HOOK, _NAN_CALL)):
    assert _call == _hook_call(_cell), f"hook call for 0x{_cell:X} is not hookcall(w:{_cell:X})"

# --- W9-2B: the divide-by-zero check (data/templates.txt `def div0`) ----------
DIV0_MSG = bytes(TPL.call("div0msg"))
_DIV0 = TPL.call("div0")
assert len(_DIV0) == 15 + 15 + 7 + 19 + len(DIV0_MSG) < 128   # jnz rel8 skips it
_DIV0_GUARD = TPL.call("div0guard")

def _divchk(minus1, push):
    """pop rcx (b), pop rax (a); b == 0 -> _DIV0; b == -1 -> `minus1`; else
    cqo; idiv rcx; then `push` (0x50 rax = quotient, 0x52 rdx = remainder)."""
    return TPL.call("divchk", [list(minus1), [push]])

def _udivchk(scalar):
    """v1's unsigned / % with the zero check in front of their own tail."""
    assert scalar[:2] == [0x59, 0x58] and scalar[2:7] == [0x31, 0xD2, 0x48, 0xF7, 0xF1]
    return _DIV0_GUARD + scalar[2:]              # .ok: xor edx,edx; div rcx; push

# --- M-VEC (W3): the polymorphic + - * ⌈ ⌊ (data/templates.txt `def poly`) ----
HOOK_BASE = 0x4F0100       # hook table (REGISTRY.md §3), 256 entries
HOOK_STRIDE = 8            # 8, not 4: `call qword [disp32]` reads 64 bits
LIST_TAG = 0x7FFF << 48    # M-TAG2/W11-1A: a list value is addr | LIST_TAG (lib/prelude.golfj)

def hook_addr(byte):
    """The hook cell for op `byte`."""
    assert 0 <= byte <= 0xFF
    return HOOK_BASE + HOOK_STRIDE * byte

def _poly(byte, scalar):
    """Wrap a scalar template in the hook-cell shape dispatch."""
    scalar = list(scalar)
    assert len(scalar) < 128, "scalar body too long to jump over with a rel8"
    tpl = TPL.call("poly", [_u32(hook_addr(byte)), scalar])
    assert len(tpl) == 38 + len(scalar) <= 255, (byte, len(tpl))
    assert tpl[16:18] == _u16(LIST_TAG >> 48), "poly's tag test is not 0x7FFF"
    return tpl

# W12-O1: the unary arithmetic atoms refuse a list (`def numchk`).
NUMCHK_BYTES = (0x80, 0x81, 0x82, 0x83, 0x84, 0x85)   # ± ⊕ ⊖ ² ⊗ ⊘
def _numchk(scalar):
    """Prefix a unary atom with the W12-O1 not-a-number check (22 bytes)."""
    tpl = TPL.call("numchk", [list(scalar)])
    assert len(tpl) == 22 + len(scalar)
    return tpl

# The data must say what these names say: every override is checked against
# the builder it is documented as, with the builder's arguments taken from the
# constants above — so a hook address typed wrong in the data file fails here.
_POLY_V1, _POLY_ATOMS = tuple(map(ord, "+-*")), (0x88, 0x89)   # + - *, ⌈ ⌊
for _b in _POLY_V1:
    assert OVERRIDES[_b] == _poly(_b, v1.TEMPLATES[chr(_b)]), f"override {_b:02X}"
for _b in _POLY_ATOMS:
    assert OVERRIDES[_b] == _poly(_b, _ATOM_TPL[_b]), f"override {_b:02X}"
for _b in map(ord, "/%"):                                       # W10-B
    assert OVERRIDES[_b] == _udivchk(v1.TEMPLATES[chr(_b)]), f"override {_b:02X}"
for _b in map(ord, ".)("):                                      # W11-1C
    assert OVERRIDES[_b] == _FLUSH_CALL + list(v1.TEMPLATES[chr(_b)]), f"override {_b:02X}"
for _b in NUMCHK_BYTES:                                         # W12-O1
    assert OVERRIDES[_b] == _numchk(_ATOM_TPL[_b]), f"override {_b:02X}"

# W13-H: ⍎ dispatches on CLOSURE RECORDS (`override 8D`): a code address lies
# below the heap floor EXEC_FLOOR, a closure record at or above it, and a
# record's kind word sits in its cell EXEC_KIND/8.
EXEC_FLOOR = 0x600000                 # == RSTACK_TOP (asserted below)
EXEC_KIND = 16                        # the record cell holding its kind word
_EXEC = OVERRIDES[0x8D]
assert len(_EXEC) == 17 and _EXEC[:1] + _EXEC[-2:] == _ATOM_TPL[0x8D]
assert _EXEC[3:7] == _u32(EXEC_FLOOR) and _EXEC[12] == EXEC_KIND


# The end-of-program exit (record 5): end hook, flush hook, then v1's exit(0).
AUTOEXIT2 = _RECORDS[5]
assert AUTOEXIT2 == bytes(_END_CALL) + bytes(_FLUSH_CALL) + v1.AUTOEXIT

# --- M-FRAME: every definition gets a private slab of locals ----------------
# The variable bank at 0x4E0000 is GLOBAL — one cell per name for the whole
# program — so a recursive word does not get fresh copies and `→n` inside
# recursion silently returns the wrong number (NEXT_STEPS.md §2).  M-FRAME adds
# a second pair of prefixes that resolve a name to a slot in the CURRENT call's
# frame instead of a bank index.
#
# Locals are OPT-IN, per definition: `⊡name … ;` reserves a frame, `:name … ;`
# is exactly what it was.  That is not fussiness, it is forced, and the reason is
# worth writing down because NEXT_STEPS.md's sketch ("give a definition a
# prologue that reserves n cells below rbp and a matching epilogue") does not
# survive contact with `^`.
#
# Whatever the prologue does to rbp, the epilogue must undo — and `^` (early
# return) IS an epilogue, is a plain template, and may appear anywhere in a body.
# A single-pass compiler does not know a definition's frame size until `;`, long
# after the `^`s have been emitted. So there are only three ways out:
#
#   1. Every word reserves the same fixed frame.  Then `^`'s template is fixed
#      and nothing needs backpatching — but EVERY word pays, including the ones
#      with no locals.  At eight slots a frame is 72 bytes instead of 8, so the
#      return stack holds ~15k frames instead of ~138k, and test/run2.sh's
#      50,000-deep recursion case dies.  Measured, not estimated: the cliff is at
#      15,728 frames.  Regressing a tested property 3x to add a feature is not a
#      trade this repo makes.
#   2. Size the frame per definition and backpatch every `^`.  There can be many
#      per word, so it needs a patch-site chain threaded through the unpatched
#      immediates, and `^` has to become compiler logic anyway.  Strictly better
#      language, materially bigger change; left in NEXT_STEPS.md.
#   3. Make the frame opt-in.  `^` still becomes compiler logic — it has to test
#      a flag — but the flag is all it tests, the frame stays one fixed size, and
#      a word that does not ask for locals emits byte-for-byte what it always
#      did.  Nothing regresses, and 50,000-deep recursion still passes.
#
# This is 3.  The one asymmetry it buys is that `⊡` words recurse ~15k deep
# where `:` words still go ~138k, which is the honest price of a frame and is
# paid only by the words that use one.
#
# M-FRAME shipped as 3 with a fixed eight-slot frame; M-FRAME2 (W9-4D) then
# did 2 on top of it, keeping the opt-in.  A ⊡ word's locals are names — `a`..`h`
# or any ‹long name› — and each takes the next slot at its first appearance in
# the definition, so a word naming k locals reserves exactly k cells:
#
#     [rbp+0] .. [rbp+8k-8]  the k local slots, in order of first appearance
#     [rbp+8k] = R           the return address
#
# A slot's displacement is known when its name is read, so `⇒`/`⇐` stay five
# bytes; only k waits for `;`.  So `⊡` emits `sub rbp, imm32` and every `^` an
# `add rbp, imm32` with the immediate left unpatched, each holding the previous
# site (the ⊡'s holds 0) — a list threaded through the immediates themselves —
# and `;` walks it writing 8k into each, then emits its own `add rbp, 8k`.  At
# most FRAME_MAX_LOCALS locals, so every displacement is a disp8 (8*15 = 120).
# The FRAME_RESERVE / FRAME_RELEASE below are the opcodes; the imm32 follows.
FRAME_MAX_LOCALS = 16
FRAME_RESERVE = bytes([0x48, 0x81, 0xED])   # sub rbp, imm32
FRAME_RELEASE = bytes([0x48, 0x81, 0xC5])   # add rbp, imm32

# --- Compiler-op byte allocations (../REGISTRY.md §1) ------------------------
# These are not atoms: there is no template for them and build_blob2() never
# emits a record.  They are bytes the COMPILER handles itself — prefixes that
# read the following byte, delimiters, definition headers — so each one costs a
# case in the tokenizer rather than a row in ATOMS.
#
# Three implementations must agree on every one of them, and this module is the
# registry all three read the byte from — loaded, since W14-L, from
# data/ops.tsv's C rows, so the names below are the mnemonics there:
#
#     self/golf2.golfj   the compiler proper, logic in v2 GOLF
#     self/seed.golfv1   the same compiler in v1 GOLF, so v1c can bootstrap it
#     boot/golfref.py    the Python oracle, off the bootstrap ladder
#
# What each case DOES is documented where it is implemented — the two GOLF
# sources carry it line by line, and test/selfcheck.sh gates that they emit
# byte-identical binaries for every input.  Adding a compiler op therefore means
# a byte here and a case in all three, which is exactly as expensive as it
# should be: a "dumb" operator is a row in ATOMS and nothing else.
_C = {mn: b for t, b, mn, _gl, _d in OPS if t == "C"}
REF_BYTE = _C["ref"] # ′  quotation: push a word's or atom's runtime address
STR_BYTE = _C["str"] # “  string literal delimiter (open and close)
SET_BYTE = _C["set"] # →x store TOS into the global variable bank
GET_BYTE = _C["get"] # ←x load from the global variable bank
CHAIN_BYTE = _C["chain"] # ⊚  define a word as a tacit chain of links
FRAME_BYTE = _C["dloc"] # ⊡  define a word owning a frame of locals
LSET_BYTE = _C["lset"] # ⇒x pop TOS into a local slot
LGET_BYTE = _C["lget"] # ⇐x push a local slot
LNAME_BYTE = _C["lname"] # ‹  opens a long name: ‹name› (M2, W9-3A)
RNAME_BYTE = _C["rname"] # ›  closes it
IMPORT_BYTE = _C["import"] # ⎘  ⎘“path“ compiles that file's bytes in place (W11-2A)
# W11-2A's compiler-only memory (../REGISTRY.md §3; layout in self/golf2.golfj):
IMPORT_PATH = 0x438000    # [len:4][path][0]; the len cell becomes `lib/` to retry
IMPORT_FDS = 0x438100     # saved dup() of fd 0 per include level, 4 bytes each
IMPORT_TABLE = 0x438200   # include-once table, 256 bytes per path: [len:4][bytes]
IMPORT_DEPTH = 8          # includes nest at most this deep
IMPORT_FILES = 60         # distinct files one compile may include
IMPORT_LEN = 250          # the longest include path, in bytes
IMPORT_DIRS = (b"", b"lib/", b"vendor/")  # where a path is looked for, in order (vendor/: W11-4A)
REC_BYTE = _C["rec"] # ⊜  ⊜‹point›‹x›‹y›; defines constructor/accessors/setters (W11-4A)
# W11-4A's compiler-only memory (../REGISTRY.md §3; layout in self/golf2.golfj):
REC_FIELDS = 0x43C000     # field k's name number at REC_FIELDS + 4*k
REC_MAX = 256             # fields one record may have
VENDOR_PATH = 0x43F000    # the C string `vendor/path` the third include try opens
ELSE_BYTE = _C["else"] # ⋄  the else of c[a⋄b] and the test of {c⋄body} (W12-A7); no memory
VINC_BYTE = _C["vinc"] # ⇡x  increment variable x in memory, inc qword [cell] (W12-Z2); no memory
VDEC_BYTE = _C["vdec"] # ⇣x  decrement it, dec qword [cell]; in a ⊡ word a named local wins
# W13-A: S2 inline blocks, ⟦ … ⟧ — an anonymous word compiled in place and
# jumped over; ⟧ pushes its address.  No memory: the compile-time stack holds
# the jmp site, the saved ⊡ flag and the tag 1000005 (see self/golf2.golfj).
BLOCK_BYTE = _C["blk"] # ⟦  opens an inline block
ENDBLOCK_BYTE = _C["endblk"] # ⟧  closes it and pushes its address
# W13-A: S1 adverbs.  A call token (an atom, a v1 arithmetic op, a one-byte
# word, a ‹long name› — and any token that compiles as one, such as a digraph)
# IMMEDIATELY followed by one of these bytes is compiled as `′token` instead
# of a call: `f€` is `′f€`.  Listed ONCE, here: build_blob2() stores the set as
# blob record ADVERB_KEY, which golf2 and the seed scan, and boot/golfref.py
# imports it.  Glyphs, in order: € ⇤ ⌿ ⊞ ⍀ ⍁ ⍸ ⍒ ⊟ ⍣, then W13's ⍂ ⍃ ⍖ ⍷
# (0xE7 0xE8 0xEA 0xEC, prelude words another W13 agent adds).
ADVERBS = _RECORDS[6]                 # data/templates.txt `rec 06`
# ... except the bytes below, which never quote: blob record UNQUOTED_KEY.
#   * the v1 stack, memory and I/O ops: no use as a function argument, and
#     `\€` "swap, then map" is real code;
#   * ∘ (0xC5) and ⊸ (0xD0), the two words that BUILD a function: `′f⊸€`
#     ("bind, then map with the result") is the idiom, so their result is what
#     the adverb takes (the W13-A audit found it in REFERENCE.md and run2.sh);
#   * ⊙ (0xA4) and ⊛ (0xA5), the 64-bit fetch and store: memory ops like
#     v1's @ !, and `cell⊙⍀` "fetch the function, then scan" is real code (the
#     integration audit found it in W13-C's ⍂).
# Everything else that reaches the compiler's default case (the other v1 ops,
# every atom, every word call) quotes.
UNQUOTED = _RECORDS[7]                # data/templates.txt `rec 07`
ADVERB_KEY = 6      # blob record keys: control bytes, never an op, so `f`
UNQUOTED_KEY = 7    # finds these two only when asked by number
DIGRAPH_BYTE = _C["dig"] # ʘB  W13-B (S6): compiles exactly as the long name ‹_dgHH› (HH = B in upper-case hex); no memory
# M2's compiler-only memory (../REGISTRY.md §3).  A long name is interned to a
# NAME NUMBER 256 + index, so the dictionary and the variable bank take it with
# their one-byte formulas unchanged (NAME_DICT + 4*name, 0x4E0000 + 8*name).
# W10-A raised the cap from 256 to 1024 and moved the dictionary and the
# forward-reference heads, with the larger name table, up to 0x480000.. —
# clear of W10-C's spill stack at 0x440000..0x47FFFF; every name,
# one-byte ones included, may now be forward-referenced.
LONG_BASE = 256           # the first long name's number
LONG_MAX = 1024           # how many long names a program may have
LONG_LEN = 60             # the longest long name, in bytes
LONG_TABLE = 0x47C000     # entry for name E is LONG_TABLE + 64*E: [len:4][bytes]
LONG_HEADS = 0x490400     # forward-reference head for ANY name N at LONG_HEADS + 4*N
NAME_DICT = 0x492000      # the compiler's dictionary: body of name N at NAME_DICT + 4*N
NAME_END = LONG_BASE + LONG_MAX          # one past the last name number (1280)
assert LONG_TABLE + 64 * LONG_BASE >= 0x480000, "long-name table below 0x480000 (W10-C spill stack)"
# ‹readname› reads every long name into the NEXT free entry before it knows
# whether the name is new, so one entry past the last (E = 1280, 0x490000) is
# scratch and must stay clear of the heads.
assert LONG_TABLE + 64 * (NAME_END + 1) <= LONG_HEADS, "long-name table (+1 scratch entry) overlaps the heads"
assert LONG_HEADS + 4 * NAME_END <= NAME_DICT, "forward heads overlap the dictionary"
assert NAME_DICT + 4 * NAME_END <= 0x4D0000, "dictionary runs into the thunk arena"
assert 0x4E0000 + 8 * NAME_END <= 0x4F0000, "variable bank runs into the runtime cells"

# --- M-MEM (W6): v2's BSS stops reserving the static list heap ---------------
# v1 asks for p_memsz = 0x800000, i.e. [0x400000, 0xC00000).  The bottom megabyte
# is the image and the fixed banks; the SEVEN megabytes above it were shared
# between a bump heap growing up from 0x500000 and the return stack growing down
# from 0xC00000.  That is both a hard ceiling on list size (~917k cells, after
# which the two met and the program died) and dead address space for every
# program that never allocates — every compiler on the ladder included.
#
# The list heap is brk-grown now (atom 0xA6 ⌸, driven by lib/prelude.golfj), so
# v2 binaries reserve only what is *statically addressed* (../REGISTRY.md §3):
#
#   0x400000..0x430000   image: header + code, at most PROGRAM_CAP (W11-1E);
#                        the compiler's own data base m = 0x410000 is BSS
#                        above ITS image, which must stay under 64 KB
#   0x430000..0x432000   W11-1C output buffer (the lowest runtime region)
#   0x494000..0x4C4000   the compiler's output buffer, compiler-only (W11-1E)
#   0x4D0000..0x4E0000   M-CHAIN runtime-thunk code arena
#   0x440000..0x480000   X/Y scratch spill stack, 4096 frames (W10-C)
#   0x4E0000..0x4E2800   →x/←x variable bank, 8 bytes per name: 256 one-byte
#                        names, then 1024 long ones (W10-A)
#   0x4F0000..0x4F0900   runtime cells, M-VEC hook table (0x4F0900.. retired)
#   0x4F1000..0x4F2000   W9-2C guard page, PROT_NONE (mprotect in STARTUP2)
#   ..0x600000           return stack, growing DOWN from the end of the segment
#
# p_memsz and the return-stack top are ONE number, not two: v1.STARTUP seeds
# rbp with the top of the BSS, so shrinking the segment necessarily moves the
# return stack with it and BOTH blob records (3 startup, 4 header) have to change
# together — hence the second override here.  It leaves ~1.07 MB of return stack
# (≈138k frames) between the W9-2C guard page and the segment end, against a compiler
# whose deepest nesting is a handful of frames.
#
# Everything ABOVE the segment is the brk heap.  The kernel starts the break at
# the page-aligned end of the last PT_LOAD and then ASLR-shifts it by up to
# 32 MB, so the heap base is NOT 0x600000 and cannot be hard-coded anywhere —
# which is exactly why the prelude reads it with `0⌸` at startup and keeps it
# in the 0x4F0034/0x4F0038 cells that only its allocator `A` reads (since
# M-TAG2 neither `T` nor the M-VEC templates look at the heap's bounds at all).
#
# The frozen v1 compiler keeps v1's numbers: data/v1.hex is untouched, so v1c
# and the `seed` it builds still run with a 0xC00000 return stack.  Only what the v2
# blob emits changes, and both golf2 and golf2' embed this blob — the fixpoint
# is unaffected.
MEMSZ = 0x200000                    # v2 p_memsz (v1: 0x800000)
RSTACK_TOP = v1.BASE + MEMSZ        # 0x600000: return-stack top AND heap floor
assert EXEC_FLOOR == RSTACK_TOP     # W13-H: ⍎'s code/closure split is the heap floor
MEMSZ_OFF = 64 + 40                 # Phdr at file offset 64; p_memsz at +40

# --- W11-1E: the program-size cap ---------------------------------------------
# A compiled program is ONE PT_LOAD at 0x400000.  Until W11-1E its p_filesz was
# v1's fixed 0x10000 and nothing checked it: bytes past 64 KB were in the file
# but never mapped, so a big program compiled cleanly and then crashed.  Now
# both compilers (self/golf2.golfj and the seed) write the image's TRUE size into
# p_filesz at the end (record 4 below still carries v1's 0x10000; it is
# overwritten), so the kernel maps exactly the file and BSS starts right after
# it — and they refuse an image past PROGRAM_CAP (golf2: `GOLF: program too
# large` on fd 2, exit 2; seed: exit 2).  The cap is where the image would meet
# the lowest region a compiled program addresses at run time, W11-1C's output
# buffer at 0x430000.  The regions below it (m = 0x410000, the old output
# buffer, W11-2A's/4A's compiler-only state at 0x438000/0x43C000) belong to the
# compiler's process only, where the image is the compiler's own (~12 KB).
# The compiler's buffer had to leave m+4096 (64 KB to 0x421000) for the free
# span between the dictionary and the thunk arena.  Both compilers spell these
# as literals (no constant import in GOLF): B = 4800512, the cap test 4997121
# (= OUTBUF + PROGRAM_CAP + 1) and the vaddr bias 606208 (= OUTBUF - BASE).
PROGRAM_CAP = 0x30000                # 196608 bytes = 192 KB, header included
OUTBUF = 0x494000                    # 4800512: the compilers' output buffer B
RUNTIME_FLOOR = 0x430000             # W11-1C output buffer: lowest runtime region
FILESZ_OFF = v1.FILESZ_OFF           # 96: where the compilers patch the size
assert v1.BASE + PROGRAM_CAP <= RUNTIME_FLOOR, "image cap overlaps runtime state"
assert OUTBUF >= NAME_DICT + 4 * NAME_END, "output buffer overlaps the dictionary"
assert OUTBUF + PROGRAM_CAP + 0x1000 <= 0x4D0000, "output buffer (+slack) runs into the thunk arena"
assert OUTBUF + PROGRAM_CAP + 1 == 4997121 and OUTBUF - v1.BASE == 606208

def header_pairs2():
    """v1's ELF header with p_memsz overridden, as (offset, value) pairs.

    Same shape as data/v1.hex's record 4: the output buffer is BSS, so only the
    non-zero bytes are stored and word `H` writes them over the zeros.
    """
    hdr = bytearray(v1.HEADER)
    assert int.from_bytes(hdr[MEMSZ_OFF:MEMSZ_OFF + 8], "little") == 0x800000, \
        "p_memsz is not where this expects it"
    hdr[MEMSZ_OFF:MEMSZ_OFF + 8] = MEMSZ.to_bytes(8, "little")
    return bytes(x for off, v in enumerate(hdr) if v for x in (off, v))

# data/templates.txt keeps record 4 as expanded bytes (`def hdrpairs`): this is
# the derivation, and it must still produce exactly those bytes.
assert _RECORDS[4] == header_pairs2(), \
    "data/templates.txt `def hdrpairs` is not header_pairs2() (v1's header, p_memsz = MEMSZ)"

assert v1.STARTUP[0] == 0xBD and len(v1.STARTUP) == 5, "STARTUP is not mov ebp,imm32"
SETUP_RSTACK = bytes(TPL.call("setuprstack"))         # mov ebp, RSTACK_TOP
assert SETUP_RSTACK == bytes([0xBD]) + RSTACK_TOP.to_bytes(4, "little")

def _check_atoms():
    """Op-byte namespace (see ../REGISTRY.md §1): an ATOMS byte must be unique
    and must not shadow a compiler prefix or a v1 template byte."""
    bs = [b for b, _mn, _gl, _tpl, _doc in ATOMS]
    dup = sorted({b for b in bs if bs.count(b) > 1})
    assert not dup, "duplicate ATOMS byte: " + ", ".join(f"0x{b:02X}" for b in dup)
    taken = set(_C.values())                      # every compiler op
    taken |= {ord(ch) for ch in v1.TEMPLATES}
    clash = sorted(set(bs) & taken)
    assert not clash, ("ATOMS byte already allocated: "
                       + ", ".join(f"0x{b:02X}" for b in clash))

# --- W8/M-TOOL: the entry-`rsp` stash -----------------------------------------
# At process entry the kernel leaves `rsp` pointing at `argc`, with `argv[i]` at
# `rsp+8+8*i`.  GOLF uses `rsp` AS its data stack, so that pointer is destroyed
# by the very first push — and `STARTUP` is the only code that runs before any
# push.  Stashing `rsp` there is therefore the ONLY way a GOLF program can ever
# reach its own command line.  The cell is 0x4F0040, decimal 5177408, and is
# 8 bytes read with `⊙` and never `@` — see ../REGISTRY.md §3 for why.
#
# An expanded-LOCAL copy rather than a change to v1.STARTUP, because the v1
# substrate in data/v1.hex is frozen ground truth and is never touched.
# The divergence costs nothing: seed.golf is compiled by v1c, which carries v1's
# blob and so emits v1's STARTUP — but the v1c -> seed rung is never compared
# against anything.  Every binary that seed and golf2 EMIT carries STARTUP2,
# because both embed the identical blob built below, so test/selfcheck.sh's
# `seed and golf2 emit byte-identical binaries` and run2.sh's `golf2 == golf2'`
# fixpoint both still hold — with every emitted binary 8 bytes longer.
#
# The stash goes in FRONT of M-MEM's `mov ebp, RSTACK_TOP` (wave 6), not in front
# of v1's `mov ebp, 0xC00000`: the two waves both rewrite record 3 and the merged
# startup has to do both jobs.  Order matters only in that the stash must precede
# anything that pushes; neither instruction does, so it reads front to back.
ARGV_CELL = 0x4F0040                    # 5177408
ARGV_STASH = bytes(TPL.call("argvstash"))           # mov [0x4F0040], rsp
assert ARGV_STASH == bytes([0x48, 0x89, 0x24, 0x25]) + ARGV_CELL.to_bytes(4, "little")

# --- W9-2C: the return-stack guard page ----------------------------------------
# Nothing in a prologue compares rbp against anything (that would cost an
# instruction on the hottest path there is), so before W9-2C a runaway recursion
# walked straight down through the 0x4F bank, the variable bank and the code
# arena, corrupting them silently, and a 200,000-deep plain recursion still
# exited 0.  The fix is a guard PAGE rather than an instruction: the one page
# directly below the return stack, [0x4F1000, 0x4F2000), is made PROT_NONE by
# STARTUP, so the first frame pushed past the bottom of the return stack faults
# (SIGSEGV, exit 139) before it can touch a single byte of anything below.
#
# Why this page, and why mprotect rather than the ELF header:
#   * the page directly below 0x4F1000 holds live state (the runtime cells, the
#     M-VEC hook table and, until W10-C moved it to 0x440000, the spill stack),
#     so the guard has to come out of the return stack itself; that costs
#     4 KB = 512 frames of ~138.7k (≈138k still).
#   * splitting the PT_LOAD so the page is simply never mapped needs a second
#     56-byte program header, which moves the code start (the `120+` in
#     golf2.golfj and seed), the entry point and every record-4 offset; the
#     mprotect is 15 bytes of record 3 and nothing else moves.
#   * one page suffices: the largest frame (a `⊡` word's) is 72 bytes and every
#     call writes its return address, so no frame can step over 4 KB unseen.
# The return value is ignored: on the off chance the kernel refuses, the program
# runs exactly as it did before W9-2C.  The `push/pop` pairs only use the stack
# AFTER the stash and leave rsp where they found it.
GUARD_LO = 0x4F1000                 # the guard page: PROT_NONE from STARTUP on
GUARD_SIZE = 0x1000                 # one page (the kernel rounds len up anyway)
RSTACK_FLOOR = GUARD_LO + GUARD_SIZE   # 0x4F2000: lowest usable return-stack byte
assert GUARD_LO % 0x1000 == 0 and RSTACK_FLOOR < RSTACK_TOP
GUARD_PAGE = bytes(TPL.call("guardpage"))   # mprotect(GUARD_LO, 1, PROT_NONE)
assert len(GUARD_PAGE) == 15 and GUARD_PAGE[3:8] == bytes([0xBF]) + GUARD_LO.to_bytes(4, "little")
STARTUP2 = _RECORDS[3]
assert STARTUP2 == ARGV_STASH + GUARD_PAGE + SETUP_RSTACK, "record 3 is not stash + guard + rbp"

def build_blob2():
    """The template blob: data/templates.txt's rec/v1ops/atoms statements, in
    order, then the 0 sentinel.  An override REPLACES the record of its byte
    (the compiler's `f` returns the FIRST record for a key, so emitting both
    would make the override a silent no-op), and each must replace one."""
    b = bytearray()
    used = set()
    def emit(key, tpl):
        if key in OVERRIDES:
            tpl = OVERRIDES[key]; used.add(key)
        assert len(tpl) <= 255, (key, len(tpl))
        return v1.rec(key, tpl)
    for kind, key, _toks, _n in TPL.stmts:
        if kind == "rec":
            b += v1.rec(key, _RECORDS[key])
        elif kind == "v1ops":
            for ch, tpl in v1.TEMPLATES.items():      # v1 op templates
                b += emit(ord(ch), tpl)
        else:
            for byte, _mn, _gl, tpl, _doc in ATOMS:   # v2 atom templates
                b += emit(byte, tpl)
    assert used == set(OVERRIDES), \
        "override with no record to replace: " + ", ".join(
            f"{k:02X}" for k in sorted(set(OVERRIDES) - used))
    b += bytes([0])                                  # sentinel
    return bytes(b)

def blob_escape():
    """The blob as GOLF source: the raw escape `<len> <that many raw bytes>.

    Both generated sources splice in exactly these bytes, so the two compilers
    are guaranteed to carry the same template table.  Byte-exact: no trailing
    newline, and the single space after the count is the escape's delimiter.
    """
    blob = build_blob2()
    return b"`" + str(len(blob)).encode() + b" " + blob

BLOB_MARKER = b"@BLOB@"          # where both sources want the blob spliced in
# W11-2A: the seed's syscall.  v1 GOLF has no syscall op, and include needs
# open/dup/dup2/close, so self/seed.golfv1's word K carries one as a raw blob
# escape spliced in at @SYS@: ⎈'s template, then `jmp +5` over the `push imm32`
# the blob escape emits after its data.  The seed's main zeroes the rel32 of
# the escape's own jmp-over once (v1's code segment is RWX), so K falls into
# these bytes from then on.  Replaced in the stripped source, before the
# template blob goes in, so the blob's raw bytes are never searched.
SYS_MARKER = b"@SYS@"
SEED_SYS = bytes(TPL.call("seedsys"))      # ⎈; jmp +5 (data/templates.txt)
GOLFV1 = os.path.join(HERE, "..", "self", "seed.golfv1")
GOLFJ = os.path.join(HERE, "..", "self", "golf2.golfj")

def build_seed():
    """self/seed.golf — the bootstrap rung, compiler logic in v1 GOLF.

    Strip self/seed.golfv1's `#` comments and whitespace and splice the blob in
    at its @BLOB@ marker, so `v1c` — which knows nothing of v2 — can compile it.

    Unlike build_golf2() the strip happens BEFORE the splice, not after: this
    source is plain ASCII with no encoding pass, so the marker is already a
    literal byte run, and stripping afterwards would eat `#` bytes inside the
    blob.  Whitespace goes for the same reason it always did — v1 ignores bytes
    <= 32, and the one load-bearing space, after the blob's byte count, is
    inside blob_escape() rather than in this file.
    """
    with open(GOLFV1, encoding="utf-8") as f:
        src = "".join(re.sub(r"#[^\n]*", "", f.read()).split())
    n = src.count(BLOB_MARKER.decode())
    if n != 1:
        raise SystemExit(f"mkblob2: expected exactly one {BLOB_MARKER.decode()} "
                         f"marker in self/seed.golfv1, found {n}")
    if src.count(SYS_MARKER.decode()) != 1:
        raise SystemExit(f"mkblob2: expected exactly one {SYS_MARKER.decode()} "
                         f"marker in self/seed.golfv1")
    sys_esc = b"`" + str(len(SEED_SYS)).encode() + b" " + SEED_SYS
    pre, post = (s.encode().replace(SYS_MARKER, sys_esc)
                 for s in src.split(BLOB_MARKER.decode()))
    return pre + blob_escape() + post

def build_golf2():
    """self/golf2.golf — the compiler proper, logic in v2 GOLF.

    Code-page encode self/golf2.golfj, then splice the blob escape in at the
    @BLOB@ marker.  The splice happens AFTER encoding, on the raw byte stream:
    the blob is arbitrary bytes and a `#` inside it would make the encoder eat
    the rest of a "line".
    """
    # Imported late, not at module scope: codepage.py imports US (ATOMS is the
    # source of truth for the code page), so a top-level import would cycle.
    import codepage
    with open(GOLFJ, encoding="utf-8") as f:
        enc = codepage.encode(f.read())
    n = enc.count(BLOB_MARKER)
    if n != 1:
        raise SystemExit(f"mkblob2: expected exactly one {BLOB_MARKER.decode()} "
                         f"marker in self/golf2.golfj, found {n}")
    return enc.replace(BLOB_MARKER, blob_escape())

# name -> generator.  main() writes every one; test/selfcheck.sh re-derives them
# and compares against what is committed.
OUTPUTS = [("seed.golf", build_seed), ("golf2.golf", build_golf2)]

def main():
    _check_atoms()
    blob = len(build_blob2())
    for name, build in OUTPUTS:
        src = build()
        out = os.path.join(HERE, "..", "self", name)
        with open(out, "wb") as f:
            f.write(src)
        sys.stderr.write(f"wrote {out}: {len(src)} bytes "
                         f"(blob {blob}, {len(ATOMS)} atoms)\n")
    # ... and the two serialised tables the GOLF tools read (data/codepage.tsv,
    # data/blob.hex), so one command regenerates everything derived from data/.
    import mktables
    mktables.main()

if __name__ == "__main__":
    main()
