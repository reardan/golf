#!/usr/bin/env python3
"""Assemble the two generated compiler sources in expanded/self/ (M-SELF).

Both are built here, and both embed the **identical** template blob from
`build_blob2()`.  They differ only in the language the compiler's *logic* is
written in:

    self/seed.golf    compiler logic in **v1 GOLF** — minimal's `mkblob.WORDS`
                      with the v2 compiler cases (′ “ → ← ⊚, the chain-link
                      case and the word X) spliced in by `WORDS2` below.  This
                      is the bootstrap rung: v1c (the frozen ../minimal
                      compiler) can compile it, and that is its only job — to
                      produce a compiler able to build golf2.golf.  The
                      WORDS2-splice mechanism lives ONLY here.

    self/golf2.golf   compiler logic in **v2 GOLF** — hand-written in
                      `self/golf2.golfj` (named variables, one op per line, the
                      language the compiler grew), code-page encoded by
                      `build_golf2()` with the blob spliced in at its `@BLOB@`
                      marker.  This is the compiler proper, and the one the
                      ladder converges on: golf2 compiles golf2.golf back to
                      itself, byte for byte.

Since M-SELF, compiler logic is authored in `self/golf2.golfj`.  `seed.golf`
exists only to bootstrap it out of v1 and is frozen in shape: it is not where
new compiler features go.  Both outputs are GENERATED — never hand-edit them;
run `python3 tools/mkblob2.py` from `expanded/` and commit the result.

New "dumb" operators still cost nothing but a template — the compiler's `e` word
dispatches ANY byte it finds in the blob, including bytes 128-255 — so adding
one means adding a row to ATOMS below.  See ../DESIGN.md.

The move toward a Jelly-style code page: operators are single bytes drawn from
the full 0..255 space, each shown via a code page glyph (../tools/codepage.py).
This module is the single source of truth for the atoms: their byte, glyph,
mnemonic, and machine-code template — and, since W8, for v2's own startup stub
(`STARTUP2`, which stashes the entry `rsp` so `argv` is reachable).
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
# NOTE: `ref` and its companion prefixes are the compiler-logic changes over v1.
# Written in pure v1 GOLF so v1c can build seed.golf.
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

_ATOM_TPL = {b: tpl for b, _mn, _gl, tpl, _d in ATOMS}
# byte -> replacement template.  build_blob2 emits the override INSTEAD of the
# original record (the compiler's `f` returns the FIRST record for a key, so
# emitting both would be a silent no-op); boot/golfref.py applies the same dict
# LAST over its TEMPLATES (dict update = last wins), so the two agree.
OVERRIDES = {b: _poly(b, golf0.TEMPLATES[chr(b)]) for b in map(ord, "+-*")}
OVERRIDES.update({b: _poly(b, _ATOM_TPL[b]) for b in (0x88, 0x89)})  # ⌈ max ⌊ min

# `ref` (byte 0x8C, glyph ′): a compiler *prefix* — read the next byte (a word
# name) and emit `push <that word's runtime address>` instead of a call.  This
# is the first change to golf2's compiler logic vs v1.  Written in pure v1 GOLF
# so v1c can still compile seed.golf — seed.golf's whole job is to be buildable
# by a compiler that has never heard of v2.
REF_BYTE = 0x8C
# ′name pushes name's address.  If name is a defined word, push its VA.  If it is
# an ATOM (a template in the blob, not a word), emit a thunk [prologue][template]
# [epilogue] inline (jumped over) and push the thunk's VA — so ′+ works without
# wrapping.  Compiler scratch m20 (jmp-site), m24 (thunk addr).
# (Since M-SELF this case — like the three below — is seed.golf's copy of logic
# that self/golf2.golfj states directly; the two must stay in step.)
#
# M-CHAIN2 lifted the body out into the word `X` (spliced in just before `t`
# below), because the chain case needs the very same "push the address of the
# word or atom named by this byte" three times over.  ′ is now the token that
# reads a name and calls it.
REF_BODY = ('"m2048+\\4*+@"[_233o m4+@m20+!0w m4+@m24+! 1E"E94E '
            'm4+@m20+@4+-m20+@!104o m24+@69632-w_^]\\_69632-104o w')
REF_WORD = ':X' + REF_BODY + ';'
REF_CASE = '"140-[_(X^]'
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
# prefixes (bytes 0x8F/0x90): read the name byte and emit an absolute 64-bit
# store/load to a per-program variable bank at 0x4E0000 (bank[name] = +8*name).
# NOTE: these are GLOBAL (one cell per name), not per-call frame — recursion
# does not get fresh copies.  Frame-based locals remain a later step.
#
# M3W: the bank was 4 bytes per name and `←x` was a `mov eax`, which zero-
# extended — `4294967296→x←x` came back 0 and `0 5-→x←x` came back 4294967291.
# Every other place a value can sit (the data stack, the atoms, list cells, the
# prelude scratch bank) has been 64 bits since M4/W4A; this was the last narrow
# one.  The fix is W4A's, exactly: stride 4 -> 8 and a REX.W on both templates.
# 256 names x 8 bytes = 2 KB, still inside the 0x4E0000-0x4F0000 hole, so no
# address had to be reallocated (../REGISTRY.md §3).  Widening in place would
# have been impossible for the same reason the scratch bank could not be: at a
# 4-byte stride x's high half IS the cell of name x+1.
SET_BYTE = 0x8F   # →   store: pop rax; mov [0x4E0000+8*name], rax
GET_BYTE = 0x90   # ←   load:  mov rax,[0x4E0000+8*name]; push rax
SET_CASE = '"143-[_(8*5111808+88o 72o 137o 4o 37o w^]'
GET_CASE = '"144-[_(8*5111808+72o 139o 4o 37o w 80o^]'

# M-CHAIN2 (byte 0xB0, glyph ⊚): a CHAIN definition.  `⊚name f g h;` is the
# tacit train the explicit spelling builds, with the compiler supplying every ′:
#
#     links   the chain is                       compiles to
#     0       identity                           nothing
#     1       f x                                a plain call
#     2       g(f x)          — atop             two plain calls
#     3       h(f x, g x)     — a fork           ′f ′g ′h ⑂
#     n>3     the fork, then the rest in turn    ′f ′g ′h ⑂ then plain calls
#
# So the count decides the shape and only the first three link bytes have to be
# buffered: the third emits the three pushes and the ⑂ call (byte 199, an
# ordinary prelude word — `199e` compiles the call to it), a fourth or later link
# is an ordinary token, and `;` flushes a 1- or 2-link chain.  No driver word, no
# new prelude state, no runtime list of quotations.
#
# Seed-side state, ../REGISTRY.md §3:  m32 in-a-chain flag · m36 link count ·
# m40/m44/m48 the buffered link bytes.  (self/golf2.golfj holds the same five in
# its variable bank as u K F G I — it owns that bank; see its header.)
CHAIN_BYTE = 0xB0
# The header is `:`'s, plus the two state cells: jmp over the body, dict[name] =
# body address, leave the jmp site on the stack for `;`, emit the prologue.
CHAIN_CASE = ('"176-[_(233o m4+@4+\\m2048+\\4*+! m4+@0w1E 1m32+!0m36+!^]')
# A token inside a chain is a LINK.  This case must sit LAST, just before the
# `e;` fallthrough: everything `t` recognizes earlier (whitespace, comments,
# digits, the structural bytes) keeps its ordinary meaning inside a chain body.
LINK_CASE = ('m32+@1-[m36+@1+m36+!'
             'm36+@1-[m40+!^]'
             'm36+@2-[m44+!^]'
             'm36+@3-[m48+! m40+@X m44+@X m48+@X 199e^]'
             'e^]')
# `;` closes a chain as well as a definition: a 1- or 2-link chain never reached
# the fork, so its links are emitted here as plain calls.  Then the ordinary
# epilogue and backpatch, which are the same for both kinds of definition.
SEMI_OLD = '"59-[_94Ek^]'
SEMI_CASE = ('"59-[_ m32+@1-[0m32+! m36+@1-[m40+@e] m36+@2-[m40+@e m44+@e]] '
             '94Ek^]')

assert mkblob.WORDS.count("w^]e;") == 1, "anchor not unique"
assert mkblob.WORDS.count(SEMI_OLD) == 1, "';' case not unique"
assert mkblob.WORDS.count(":t ") == 1, "':t' anchor not unique"
WORDS2 = mkblob.WORDS.replace(
    "w^]e;", "w^]" + REF_CASE + STR_CASE + SET_CASE + GET_CASE
             + CHAIN_CASE + LINK_CASE + "e;")
WORDS2 = WORDS2.replace(SEMI_OLD, SEMI_CASE)
# X is called from inside `t`, so it has to be defined before it — and after
# everything it calls itself (o, w, E, and the templates), which `h` is the last
# of.  v1's own words are unchanged; this is an addition, like the cases above.
WORDS2 = WORDS2.replace(":t ", REF_WORD + ":t ")

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
# p_memsz and the return-stack top are ONE number, not two: golf0.STARTUP seeds
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
# The frozen v1 compiler keeps v1's numbers: minimal/ is untouched, so v1c and
# the `seed` it builds still run with a 0xC00000 return stack.  Only what the v2
# blob emits changes, and both golf2 and golf2' embed this blob — the fixpoint
# is unaffected.
MEMSZ = 0x200000                    # v2 p_memsz (v1: 0x800000)
RSTACK_TOP = golf0.BASE + MEMSZ     # 0x600000: return-stack top AND heap floor
MEMSZ_OFF = 64 + 40                 # Phdr at file offset 64; p_memsz at +40

def header_pairs2():
    """v1's ELF header with p_memsz overridden, as (offset, value) pairs.

    Same shape as mkblob.header_pairs(): the output buffer is BSS, so only the
    non-zero bytes are stored and word `H` writes them over the zeros.
    """
    hdr = bytearray(golf0.HEADER)
    assert int.from_bytes(hdr[MEMSZ_OFF:MEMSZ_OFF + 8], "little") == 0x800000, \
        "p_memsz is not where this expects it"
    hdr[MEMSZ_OFF:MEMSZ_OFF + 8] = MEMSZ.to_bytes(8, "little")
    return bytes(x for off, v in enumerate(hdr) if v for x in (off, v))

assert golf0.STARTUP[0] == 0xBD and len(golf0.STARTUP) == 5, "STARTUP is not mov ebp,imm32"
SETUP_RSTACK = bytes([0xBD]) + RSTACK_TOP.to_bytes(4, "little")  # mov ebp, RSTACK_TOP

def _check_atoms():
    """Op-byte namespace (see ../REGISTRY.md §1): an ATOMS byte must be unique
    and must not shadow a compiler prefix or a v1 template byte."""
    bs = [b for b, _mn, _gl, _tpl, _doc in ATOMS]
    dup = sorted({b for b in bs if bs.count(b) > 1})
    assert not dup, "duplicate ATOMS byte: " + ", ".join(f"0x{b:02X}" for b in dup)
    taken = {REF_BYTE, STR_BYTE, SET_BYTE, GET_BYTE, CHAIN_BYTE}
    taken |= {ord(ch) for ch in golf0.TEMPLATES}
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
# An expanded-LOCAL copy rather than a change to golf0.STARTUP, because
# ../minimal is the frozen ground-truth bootstrap root and is never touched.
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
    b += mkblob.rec(1, golf0.PROLOGUE)
    b += mkblob.rec(2, mkblob.COND)
    b += mkblob.rec(3, STARTUP2)                     # M-TOOL stash + M-MEM rbp
    b += mkblob.rec(4, header_pairs2())              # M-MEM: shrunken p_memsz
    b += mkblob.rec(5, golf0.AUTOEXIT)
    used = set()
    def emit(key, tpl):
        """One record per op byte — the M-VEC override REPLACES the scalar one."""
        if key in OVERRIDES:
            tpl = OVERRIDES[key]; used.add(key)
        assert len(tpl) <= 255, (key, len(tpl))
        return mkblob.rec(key, tpl)
    for ch, tpl in golf0.TEMPLATES.items():          # v1 op templates
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

def build_seed():
    """self/seed.golf — the bootstrap rung, compiler logic in v1 GOLF.

    v1's own compiler source (mkblob.WORDS) with the four v2 compiler cases
    spliced in (WORDS2), so `v1c` — which knows nothing of v2 — can compile it.
    """
    code = lambda s: mkblob.golf(s.replace(" ", "")).encode()
    return b"".join([code(WORDS2), code(mkblob.INIT),
                     blob_escape(), code(mkblob.TAIL)])

BLOB_MARKER = b"@BLOB@"          # where golf2.golfj wants the blob spliced in
GOLFJ = os.path.join(HERE, "..", "self", "golf2.golfj")

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
