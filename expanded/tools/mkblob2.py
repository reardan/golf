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
`python3 tools/mkblob2.py` from `expanded/`, and commit the result.

v1 itself is no longer a source tree here.  Its op templates and ELF header
arrive as data — `data/v1.hex`, read by `boot/v1.py` — and the compiler built
from it arrives as a pinned release binary (`../SEEDS`, `tools/seed.sh`).  The
tree they came from is frozen on the `minimal` branch.

New "dumb" operators still cost nothing but a template — the compiler's `e` word
dispatches ANY byte it finds in the blob, including bytes 128-255 — so adding
one means adding a row to ATOMS below.  See ../DESIGN.md.

The move toward a Jelly-style code page: operators are single bytes drawn from
the full 0..255 space, each shown via a code page glyph (../tools/codepage.py).
This module is the single source of truth for the atoms: their byte, glyph,
mnemonic, and machine-code template — and, since W8, for v2's own startup stub
(`STARTUP2`, which stashes the entry `rsp` so `argv` is reachable).
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "boot"))
import v1       # the frozen v1 substrate: templates, ELF header, blob helpers

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
    # partner `ref` (push a word's address) is a compiler prefix, not an atom —
    # REF_BYTE below, with a case in each of the three compilers — and together
    # they give higher-order functions (map/fold).
    (0x8D, "exec", "⍎", [0x58, 0xFF, 0xD0],               "pop a word address, call it"),
    # Raw scalar ops — byte-for-byte copies of today's scalar templates for
    # `+ - * ⌊ ⌈ <`.  M-VEC will make those bare ops *polymorphic* (dispatch on
    # int-vs-list); the prelude's own pointer/flag arithmetic must never pay for
    # (or be changed by) that dispatch, so it moves to these.  Reserved for
    # prelude-internal use: they are guaranteed to stay pure scalar forever.
    (0x91, "radd", "﹢", [0x58, 0x48, 0x01, 0x04, 0x24],   "raw add (never polymorphic)"),
    (0x92, "rsub", "﹣", [0x58, 0x48, 0x29, 0x04, 0x24],   "raw sub (never polymorphic)"),
    (0x93, "rmul", "﹡", [0x59, 0x58, 0x48, 0x0F, 0xAF, 0xC1, 0x50],
                                                          "raw mul (never polymorphic)"),
    (0x94, "rmin", "⊓", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x48, 0x0F, 0x47, 0xC1, 0x50],
                                                          "raw unsigned min (never polymorphic)"),
    (0x95, "rmax", "⊔", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x48, 0x0F, 0x42, 0xC1, 0x50],
                                                          "raw unsigned max (never polymorphic)"),
    (0x96, "rlt",  "﹤", [0x59, 0x58, 0x48, 0x29, 0xC8, 0x48, 0x19, 0xC0, 0x50],
                                                          "raw unsigned less -1/0 (never polymorphic)"),
    # M4 atoms: signed compare, shifts, 64-bit cells.  v1's `<` `»` are UNSIGNED
    # and its `@` `!` are 32-bit; these are the signed/64-bit counterparts at new
    # bytes.  Widening `!` in place would corrupt the compiler's own 4-byte-strided
    # dictionary, so `⊙`/`⊛` are additions and the swap is deferred to M4 proper.
    (0xA0, "slt", "≺", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x0F, 0x9C, 0xC0,
                        0x0F, 0xB6, 0xC0, 0x48, 0xF7, 0xD8, 0x50],
                                                          "a b -> (a<b signed ? -1 : 0)"),
    (0xA1, "sgt", "≻", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x0F, 0x9F, 0xC0,
                        0x0F, 0xB6, 0xC0, 0x48, 0xF7, 0xD8, 0x50],
                                                          "a b -> (a>b signed ? -1 : 0)"),
    (0xA2, "shl", "≪", [0x59, 0x48, 0xD3, 0x24, 0x24],    "shift left (by TOS)"),
    (0xA3, "sar", "≫", [0x59, 0x48, 0xD3, 0x3C, 0x24],    "arithmetic shift right (by TOS)"),
    (0xA4, "fetch", "⊙", [0x58, 0x48, 0x8B, 0x00, 0x50],  "addr -> v, full 64-bit cell"),
    (0xA5, "store", "⊛", [0x58, 0x59, 0x48, 0x89, 0x08],  "v addr -> ; full 64-bit cell"),
    # M-MEM (wave 6): the brk(2) syscall — `0⌸` reads the current program break,
    # `addr⌸` moves it there.  Either way the kernel returns the break IN EFFECT
    # afterwards (the OLD one if it refused), so a caller can always recompute
    # the true span from the return value instead of assuming it got what it
    # asked for.  This is what lets lib/prelude.golfj grow the list heap on
    # demand rather than living inside a fixed BSS reservation.  syscall
    # clobbers only rcx/r11, which no template holds across an op.
    (0xA6, "brk",   "⌸", [0x5F, 0x6A, 0x0C, 0x58, 0x0F, 0x05, 0x50],
                                                          "addr -> break; brk(2)"),
    # The language's first general syscall (M-TOOL): until now GOLF's whole I/O
    # surface was `(` and `)`, one byte on fd 0 / fd 1, so a GOLF program could
    # not open a file, read argv, or exit with a code.  `⎈` takes THREE arguments
    # and a number — `a1 a2 a3 num ⎈ -> result` — popped rax, rdx, rsi, rdi so the
    # source reads left to right in natural argument order, with `0` pushed for
    # arguments a call does not use.  Three is exactly enough for everything the
    # repo's own build scripts need: `open`(path,flags,mode) — number 2, NOT
    # `openat`, which would want a 4th argument in r10 and therefore its own op —
    # plus read/write(fd,buf,n), close, exit, brk and lseek.  The kernel's return
    # value is pushed back unchanged, negative errno on failure.  `syscall`
    # clobbers rcx and r11, which is harmless here: no GOLF value is ever live in
    # a register across ops (the data stack IS rsp, every template starts and ends
    # on it), and rbp — the return-stack pointer — is untouched by the kernel.
    (0xA7, "sys", "⎈", [0x58, 0x5A, 0x5E, 0x5F, 0x0F, 0x05, 0x50],
                                                          "a1 a2 a3 num -> result: raw syscall"),
]

# --- M-VEC (W3): polymorphic templates for the bare + - * ⌈ ⌊ ----------------
# These five op bytes keep their v1/atom scalar body but get a shape-dispatch
# preamble in front of it.  Layout (38 bytes + the untouched scalar body):
#
#     48 83 3C 25 <hook> 00     cmp qword [hook], 0     ; per-op hook cell
#     74 1B                     je  .scalar             ; no dispatcher -> scalar
#     48 8B 04 24               mov rax, [rsp]          ; b  (TOS)
#     48 0B 44 24 08            or  rax, [rsp+8]        ; | a
#     3B 04 25 <heapbase>       cmp eax, [heap base]
#     72 09                     jb  .scalar             ; both below the heap
#     FF 14 25 <hook>           call qword [hook]       ; (a b) still on the stack
#     EB <len(scalar)>          jmp .done
#   .scalar:  <the original scalar template, byte for byte>
#   .done:
#
# Three properties make this safe:
#
#   * **Off by default.**  The hook table (../REGISTRY.md §3: 256 cells of 8
#     bytes at 0x4F0100, indexed by op byte) is BSS, so a program that does not
#     install a dispatcher — every compiler binary on the bootstrap ladder, which
#     never runs lib/prelude.golfj — takes the 9-byte check and then exactly the
#     old scalar path.  That is why the ladder's `golf2 == golf2'` fixpoint
#     survives: both are built from self/golf2.golf, embed the same blob, and
#     emit the same bytes.  (v1c carries v1's blob and so emits different code —
#     that divergence is absorbed at the v1c -> seed rung, which is never
#     compared against anything.)
#   * **The filter is conservative, never authoritative.**  `or` only sets bits,
#     so (a|b) >= a: if EITHER operand is a heap address the compare cannot send
#     us to the scalar path.  False positives are fine and expected (a -1 flag
#     from `<` looks huge): they reach the PRELUDE's dispatcher D, which re-tests
#     both operands exactly and applies the raw scalar op when both are ints.
#   * **Stack-neutral.**  `call` pushes its return address on the DATA stack and
#     the hooked word's PROLOGUE parks it on the return stack, so the word sees
#     exactly (a b) and leaves one result — the scalar path's net effect.
#
# The heap-base compare is 32-bit on purpose.  0x4F0034 is a 4-byte cell whose
# neighbour 0x4F0038 (the heap span) is non-zero, so a 64-bit read there would
# yield span<<32 | base and put the bound above every real address, disabling
# dispatch entirely.  Heap addresses are < 2^32 and low32(a|b) >= low32(a) = a,
# so the 32-bit test keeps the same one-sided guarantee.
HOOK_BASE = 0x4F0100       # hook table (REGISTRY.md §3), 256 entries
HOOK_STRIDE = 8            # 8, not 4: `call qword [disp32]` reads 64 bits
HEAP_BASE_CELL = 0x4F0034  # runtime heap base, installed by the prelude's init

def hook_addr(byte):
    """The hook cell for op `byte`."""
    assert 0 <= byte <= 0xFF
    return HOOK_BASE + HOOK_STRIDE * byte

def _u32(v):
    return list(v.to_bytes(4, "little"))

def _poly(byte, scalar):
    """Wrap a scalar template in the hook-cell shape dispatch shown above."""
    hook, base, scalar = _u32(hook_addr(byte)), _u32(HEAP_BASE_CELL), list(scalar)
    assert len(scalar) < 128, "scalar body too long to jump over with a rel8"
    fast = ([0x48, 0x8B, 0x04, 0x24]                  # mov rax, [rsp]
            + [0x48, 0x0B, 0x44, 0x24, 0x08]          # or  rax, [rsp+8]
            + [0x3B, 0x04, 0x25] + base               # cmp eax, [heap base]
            + [0x72, 9]                               # jb  .scalar  (7+2 ahead)
            + [0xFF, 0x14, 0x25] + hook               # call qword [hook]
            + [0xEB, len(scalar)])                    # jmp .done
    assert fast[17] == 9 and len(fast) - 18 == 9, "jb displacement"
    tpl = ([0x48, 0x83, 0x3C, 0x25] + hook + [0x00]   # cmp qword [hook], 0
           + [0x74, len(fast)]                        # je  .scalar
           + fast + scalar)
    assert len(tpl) == 38 + len(scalar) <= 255, (byte, len(tpl))
    return tpl

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
# Layout, with R the address the return address is stored at:
#
#     [rbp+0] .. [rbp+56]   the eight local slots, a..h
#     [rbp+64] = R          the return address
#
# A slot's displacement is 8*(name-'a') and does not depend on how many slots
# the word actually uses, which is what lets `⇒`/`⇐` be fixed-size templates.
# Eight slots is the compromise: the compiler's own busiest word holds five
# variables at once, so eight is comfortable, while a slot per letter would cost
# 216 bytes a frame.
FRAME_SLOTS = 8
FRAME_BYTES = 8 * FRAME_SLOTS
FRAME_RESERVE = bytes([0x48, 0x83, 0xED, FRAME_BYTES])   # sub rbp, 64
FRAME_RELEASE = bytes([0x48, 0x83, 0xC5, FRAME_BYTES])   # add rbp, 64

_ATOM_TPL = {b: tpl for b, _mn, _gl, tpl, _d in ATOMS}
# byte -> replacement template.  build_blob2 emits the override INSTEAD of the
# original record (the compiler's `f` returns the FIRST record for a key, so
# emitting both would be a silent no-op); boot/golfref.py applies the same dict
# LAST over its TEMPLATES (dict update = last wins), so the two agree.
OVERRIDES = {b: _poly(b, v1.TEMPLATES[chr(b)]) for b in map(ord, "+-*")}
OVERRIDES.update({b: _poly(b, _ATOM_TPL[b]) for b in (0x88, 0x89)})  # ⌈ max ⌊ min

# --- Compiler-op byte allocations (../REGISTRY.md §1) ------------------------
# These are not atoms: there is no template for them and build_blob2() never
# emits a record.  They are bytes the COMPILER handles itself — prefixes that
# read the following byte, delimiters, definition headers — so each one costs a
# case in the tokenizer rather than a row in ATOMS.
#
# Three implementations must agree on every one of them, and this module is the
# registry all three read the byte from:
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
REF_BYTE = 0x8C     # ′  quotation: push a word's or atom's runtime address
STR_BYTE = 0x8E     # “  string literal delimiter (open and close)
SET_BYTE = 0x8F     # →x store TOS into the global variable bank
GET_BYTE = 0x90     # ←x load from the global variable bank
CHAIN_BYTE = 0xB0   # ⊚  define a word as a tacit chain of links
FRAME_BYTE = 0xB1   # ⊡  define a word owning a frame of locals
LSET_BYTE = 0xB2    # ⇒x pop TOS into a local slot
LGET_BYTE = 0xB3    # ⇐x push a local slot

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
#   0x400000..0x421000   image: code, compiler data base 0x410000, output buffer
#   0x4D0000..0x4E0000   M-CHAIN runtime-thunk code arena
#   0x4E0000..0x4E0400   →x/←x variable bank
#   0x4F0000..0x4F1000   runtime cells, M-VEC hook table, scratch spill stack
#   ..0x600000           return stack, growing DOWN from the end of the segment
#
# p_memsz and the return-stack top are ONE number, not two: v1.STARTUP seeds
# rbp with the top of the BSS, so shrinking the segment necessarily moves the
# return stack with it and BOTH blob records (3 startup, 4 header) have to change
# together — hence the second override here.  It leaves ~1.08 MB of return stack
# (≈138k frames) between the 0x4F bank and the segment end, against a compiler
# whose deepest nesting is a handful of frames.
#
# Everything ABOVE the segment is the brk heap.  The kernel starts the break at
# the page-aligned end of the last PT_LOAD and then ASLR-shifts it by up to
# 32 MB, so the heap base is NOT 0x600000 and cannot be hard-coded anywhere —
# which is exactly why the prelude reads it with `0⌸` at startup and publishes
# it in the 0x4F0034/0x4F0038 bounds cells the M-VEC templates and `T` read.
#
# The frozen v1 compiler keeps v1's numbers: data/v1.hex is untouched, so v1c
# and the `seed` it builds still run with a 0xC00000 return stack.  Only what the v2
# blob emits changes, and both golf2 and golf2' embed this blob — the fixpoint
# is unaffected.
MEMSZ = 0x200000                    # v2 p_memsz (v1: 0x800000)
RSTACK_TOP = v1.BASE + MEMSZ        # 0x600000: return-stack top AND heap floor
MEMSZ_OFF = 64 + 40                 # Phdr at file offset 64; p_memsz at +40

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

assert v1.STARTUP[0] == 0xBD and len(v1.STARTUP) == 5, "STARTUP is not mov ebp,imm32"
SETUP_RSTACK = bytes([0xBD]) + RSTACK_TOP.to_bytes(4, "little")  # mov ebp, RSTACK_TOP

def _check_atoms():
    """Op-byte namespace (see ../REGISTRY.md §1): an ATOMS byte must be unique
    and must not shadow a compiler prefix or a v1 template byte."""
    bs = [b for b, _mn, _gl, _tpl, _doc in ATOMS]
    dup = sorted({b for b in bs if bs.count(b) > 1})
    assert not dup, "duplicate ATOMS byte: " + ", ".join(f"0x{b:02X}" for b in dup)
    taken = {REF_BYTE, STR_BYTE, SET_BYTE, GET_BYTE, CHAIN_BYTE}
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
ARGV_STASH = bytes([0x48, 0x89, 0x24, 0x25, 0x40, 0x00, 0x4F, 0x00])
#            mov [0x4F0040], rsp
STARTUP2 = ARGV_STASH + SETUP_RSTACK

def build_blob2():
    b = bytearray()
    b += v1.rec(1, v1.PROLOGUE)
    b += v1.rec(2, v1.COND)
    b += v1.rec(3, STARTUP2)                     # M-TOOL stash + M-MEM rbp
    b += v1.rec(4, header_pairs2())              # M-MEM: shrunken p_memsz
    b += v1.rec(5, v1.AUTOEXIT)
    used = set()
    def emit(key, tpl):
        """One record per op byte — the M-VEC override REPLACES the scalar one."""
        if key in OVERRIDES:
            tpl = OVERRIDES[key]; used.add(key)
        assert len(tpl) <= 255, (key, len(tpl))
        return v1.rec(key, tpl)
    for ch, tpl in v1.TEMPLATES.items():          # v1 op templates
        b += emit(ord(ch), tpl)
    for byte, _mn, _gl, tpl, _doc in ATOMS:          # v2 atom templates
        b += emit(byte, tpl)
    assert used == set(OVERRIDES), "override with no record to replace"
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
    pre, post = src.split(BLOB_MARKER.decode())
    return pre.encode() + blob_escape() + post.encode()

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

if __name__ == "__main__":
    main()
