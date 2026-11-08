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

# --- W9-2B: the divide-by-zero check shared by the ÷ ∣ templates ------------
# Templates are copied inline at every use, and into ′-thunks and chain links,
# so the check must be position-independent: the message travels INSIDE the
# template and is addressed rip-relative.  No shared stub at a fixed address —
# that would couple every template to the emitter's layout for ~40 bytes saved
# per use, and most programs use ÷/∣ once or never.  The data stack is rsp, so
# push/pop imm8 are the short way to load the syscall registers; nothing on it
# matters any more once we are on the way out.
#
# W11-1C: the flush hook.  The prelude's printers (Ṅ ⍕ ␤ 🗲 ⊐) append to an 8 KB
# buffer (0x430000, REGISTRY.md §3) instead of writing one byte per write(2).
# What is still pending must reach its fd before the process exits and before
# anything touches the fds raw, so every template that exits or does raw I/O —
# `.` `)` `(`, the end-of-program exit (AUTOEXIT2) and the divide-by-zero exit
# below — first calls through ONE hook cell: the 1C runtime cell 0x4F0990
# (5179792), which the prelude's init fills with the address of `‹flush›`.
# Like the M-VEC hooks it is BSS, so a program without the prelude (the
# compiler itself among them) sees 0 and runs what it ran before plus a load, a
# test and a not-taken jump.  Absolute addressing, no rip: the sequence is
# copied inline into templates, ′-thunks and chain links.  rax is the only
# register it touches (the callee is a GOLF word: data stack rsp and return
# stack rbp are preserved), and every user reloads rax afterwards.
FLUSH_HOOK = 0x4F0990
def _hook_call(cell):
    """`call [cell]` when the cell is non-zero: 15 bytes, absolute, rax only."""
    return ([0x48, 0x8B, 0x04, 0x25] + list(cell.to_bytes(4, "little"))
            + [0x48, 0x85, 0xC0]                 # mov rax,[hook]; test rax,rax
            + [0x74, 0x02, 0xFF, 0xD0])          # jz .no; call rax; .no:
_FLUSH_CALL = _hook_call(FLUSH_HOOK)
assert len(_FLUSH_CALL) == 15
# W11-3A: the divide-by-zero hook.  A second cell of the same shape, the 3A
# runtime cell 0x4F0B10 (5180176), which the prelude's init fills with the
# address of ‹_3a_div0›.  It is called FIRST, before the flush: with a ‹catch›
# armed, ‹_3a_div0› raises `divide by zero` through ‹throw›'s unwinding and
# never comes back; with none it returns at once and the template goes on to
# flush, print and exit exactly as before.  So ÷ ∣ / % are catchable at 15
# bytes per use, and a program without the prelude (every compiler binary)
# sees 0 and falls through.
DIV0_HOOK = 0x4F0B10
_DIV0_CALL = _hook_call(DIV0_HOOK)

DIV0_MSG = b"GOLF: divide by zero\n"
_DIV0 = (_DIV0_CALL                               # W11-3A: a ‹catch› takes it
         + _FLUSH_CALL                            # W11-1C: prior output first
         + [0x48, 0x8D, 0x35] + list((19).to_bytes(4, "little"))  # lea rsi,[rip+19]
         + [0x6A, 0x02, 0x5F]                     # push 2;  pop rdi   fd 2
         + [0x6A, len(DIV0_MSG), 0x5A]            # push n;  pop rdx   length
         + [0x6A, 0x01, 0x58]                     # push 1;  pop rax   write
         + [0x0F, 0x05]                           # syscall
         + [0x6A, 0x01, 0x5F]                     # push 1;  pop rdi   status 1
         + [0x6A, 0x3C, 0x58]                     # push 60; pop rax   exit
         + [0x0F, 0x05]                           # syscall
         + list(DIV0_MSG))                        # (19 bytes of code above)
assert len(_DIV0) == 15 + 15 + 7 + 19 + len(DIV0_MSG) < 128   # jnz rel8 skips it

# pop rcx (b); pop rax (a); b == 0 -> _DIV0.  The common head of all four
# checked division templates (÷ ∣ and, since W10-B, v1's / %).
_DIV0_GUARD = ([0x59, 0x58]                       # pop rcx; pop rax
               + [0x48, 0x85, 0xC9]               # test rcx, rcx
               + [0x75, len(_DIV0)] + _DIV0)      # jnz .ok ; else die

def _divchk(minus1, push):
    """pop rcx (b), pop rax (a); b == 0 -> _DIV0; b == -1 -> `minus1` (the
    wrapped result, no idiv: INT64_MIN / -1 would trap); else cqo; idiv rcx;
    then `push` (0x50 rax = quotient, 0x52 rdx = remainder)."""
    return (_DIV0_GUARD
            + [0x48, 0x83, 0xF9, 0xFF]            # .ok: cmp rcx, -1
            + [0x75, len(minus1) + 2] + minus1    # jne .div ; ÷: neg rax · ∣: xor edx,edx
            + [0xEB, 0x05]                        # jmp .done
            + [0x48, 0x99, 0x48, 0xF7, 0xF9]      # .div: cqo; idiv rcx
            + [push])                             # .done: push rax / rdx

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
    (0x80, "neg", "±", [0x58, 0x48, 0xF7, 0xD8, 0x50],   "negate TOS (a list: elementwise, any depth)"),
    (0x81, "inc", "⊕", [0x48, 0xFF, 0x04, 0x24],         "TOS + 1 (a list: elementwise, any depth)"),
    (0x82, "dec", "⊖", [0x48, 0xFF, 0x0C, 0x24],         "TOS - 1 (a list: elementwise, any depth)"),
    (0x83, "sqr", "²", [0x58, 0x48, 0x0F, 0xAF, 0xC0, 0x50], "TOS * TOS (a list: elementwise, any depth)"),
    (0x84, "dbl", "⊗", [0x48, 0xD1, 0x24, 0x24],         "TOS * 2 (a list: elementwise, any depth)"),
    (0x85, "hlv", "⊘", [0x48, 0xD1, 0x2C, 0x24],         "TOS >> 1 (a list: elementwise, any depth)"),
    # Comparison / selection / signed arithmetic (result -1/0 like '<')
    (0x86, "gt",  "»", [0x59, 0x58, 0x48, 0x39, 0xC1, 0x48, 0x19, 0xC0, 0x50],
                                                          "a b -> (a>b unsigned ? -1 : 0)"),
    (0x87, "eq",  "≡", [0x59, 0x58, 0x48, 0x29, 0xC8, 0x48, 0x83, 0xE8, 0x01,
                        0x48, 0x19, 0xC0, 0x50],          "a b -> (a==b ? -1 : 0)"),
    # W9-1A: ⌈ ⌊ are SIGNED (cmp rax,rcx then cmovl / cmovg), like ÷ ∣ ≺ ≻ and
    # the rest of the language's arithmetic; unsigned max/min stay available as
    # the raw ⊔ ⊓ below, which the prelude's pointer math relies on.
    (0x88, "max", "⌈", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x48, 0x0F, 0x4C, 0xC1, 0x50],
                                                          "a b -> max(a,b) signed"),
    (0x89, "min", "⌊", [0x59, 0x58, 0x48, 0x39, 0xC8, 0x48, 0x0F, 0x4F, 0xC1, 0x50],
                                                          "a b -> min(a,b) signed"),
    # W9-2B: ÷ ∣ are CHECKED.  A zero divisor writes `GOLF: divide by zero` to
    # fd 2 and exits 1 (_DIV0, below) instead of dying of SIGFPE; a divisor of
    # -1 skips idiv (INT64_MIN / -1 is the other #DE) and gives the wrapped
    # result — ÷ is `neg`, so INT64_MIN ÷ -1 = INT64_MIN, and ∣ is 0.
    (0x8A, "sdv", "÷", _divchk([0x48, 0xF7, 0xD8], 0x50),
                                                          "a b -> a/b signed (b=0: error exit 1)"),
    (0x8B, "smd", "∣", _divchk([0x31, 0xD2], 0x52),
                                                          "a b -> a%b signed (b=0: error exit 1)"),
    # Quotations: exec is an indirect call (pop a word address, call it).  Its
    # partner `ref` (push a word's address) is a compiler prefix, not an atom —
    # REF_BYTE below, with a case in each of the three compilers — and together
    # they give higher-order functions (map/fold).
    (0x8D, "exec", "⍎", [0x58, 0xFF, 0xD0],               "pop a word address, call it"),
    # Raw scalar ops — byte-for-byte copies of the original scalar templates for
    # `+ - * ⌊ ⌈ <` (⊓ ⊔ keep the UNSIGNED cmova/cmovb that ⌊ ⌈ had before W9-1A
    # made those signed — pointer math wants unsigned).  M-VEC will make those bare ops *polymorphic* (dispatch on
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
    # W11-3A: the two stack-pointer atoms behind ‹catch› / ‹throw› — the
    # runtime's setjmp/longjmp.  The data stack IS rsp and the return stack is
    # rbp (a word's prologue parks the `call`'s return address at [rbp], so
    # inside a word body rsp holds only data).  `push rsp` stores the value rsp
    # had BEFORE that push, so ⊷'s `sp` is exactly "the stack as it was before
    # the atom": `⊷ … sp bp ⊶` puts both stacks back where they were at ⊷,
    # dropping everything pushed since.  ⊶ pops bp first, then `pop rsp` loads
    # rsp from [rsp] (the pop's own increment is overwritten), so both values
    # are consumed before rsp moves.  After ⊶ the CURRENT word's epilogue
    # returns through [rbp] — the return address of whichever word ran ⊷ —
    # which is what makes ‹throw› come back out of ‹catch›'s helper
    # (lib/prelude.golfj, W11-3A section).
    (0xA8, "spr", "⊷", [0x54, 0x55],                      "-> sp bp: push rsp (as before the atom), then rbp"),
    (0xA9, "spw", "⊶", [0x5D, 0x5C],                      "sp bp ->: set rbp, then rsp (both stacks jump)"),
    # W13-B: bit atoms.  RAW like the other bitwise atoms (no list dispatch,
    # no not-a-number check).  popcnt / tzcnt / lzcnt are F3 48 0F B8/BC/BD
    # (the CPU baseline has popcnt + bmi1 + abm); tzcnt and lzcnt give 64 for
    # 0.  The low bit is x & -x, written without BMI1's blsi.
    (0xAA, "pcnt", "♯", [0x58, 0xF3, 0x48, 0x0F, 0xB8, 0xC0, 0x50],
                                                          "x -> number of 1 bits (popcount)"),
    (0xAB, "ctz", "⊣", [0x58, 0xF3, 0x48, 0x0F, 0xBC, 0xC0, 0x50],
                                                          "x -> trailing zero bits (64 for 0)"),
    (0xAC, "clz", "⊢", [0x58, 0xF3, 0x48, 0x0F, 0xBD, 0xC0, 0x50],
                                                          "x -> leading zero bits (64 for 0)"),
    (0xAD, "lsb", "⊥", [0x48, 0x8B, 0x04, 0x24, 0x48, 0xF7, 0xD8, 0x48, 0x21, 0x04, 0x24],
                                                          "x -> x & -x, the lowest set bit (0 for 0)"),
]

# --- M-VEC (W3): polymorphic templates for the bare + - * ⌈ ⌊ ----------------
# These five op bytes keep their v1/atom scalar body but get a shape-dispatch
# preamble in front of it.  Layout (38 bytes + the untouched scalar body):
#
#     48 83 3C 25 <hook> 00     cmp qword [hook], 0     ; per-op hook cell
#     74 1B                     je  .scalar             ; no dispatcher -> scalar
#     66 81 7C 24 06 FF 7F      cmp word [rsp+6], 0x7FFF  ; b's tag  (TOS)
#     74 09                     je  .call
#     66 81 7C 24 0E FF 7F      cmp word [rsp+14], 0x7FFF ; a's tag
#     75 09                     jne .scalar             ; neither is a list
#   .call:
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
#   * **The filter is EXACT (M-TAG2).**  A list value is its heap address with
#     top 16 bits 0x7FFF — `addr | 0x7FFF<<48`, so `v >> 48 == 0x7FFF` (W11-1A;
#     it was bit 48, `addr | 2^48`, through W10) — and the top 16 bits of a
#     little-endian qword are the word at byte offset 6.  So
#     `cmp word [rsp+6],0x7FFF` is exactly `T`, with no cell to read: an operand
#     is a list iff its high word is 0x7FFF.  Negative integers (high word
#     0xFFFF) and everything below 0x7FFF<<48 take the scalar path without ever
#     reaching the prelude; the only integers that dispatch are those in
#     [0x7FFF<<48, 2^63), the band the tag sacrifices.  Until M-TAG2 this was a conservative `(a|b) <u heap base`
#     against the 32-bit cell 0x4F0034 — a range test that sent a -1 flag to the
#     prelude and let an integer that happened to equal a heap address in.
#   * **Stack-neutral.**  `call` pushes its return address on the DATA stack and
#     the hooked word's PROLOGUE parks it on the return stack, so the word sees
#     exactly (a b) and leaves one result — the scalar path's net effect.
HOOK_BASE = 0x4F0100       # hook table (REGISTRY.md §3), 256 entries
HOOK_STRIDE = 8            # 8, not 4: `call qword [disp32]` reads 64 bits
LIST_TAG = 0x7FFF << 48    # M-TAG2/W11-1A: a list value is addr | LIST_TAG (lib/prelude.golfj)

def hook_addr(byte):
    """The hook cell for op `byte`."""
    assert 0 <= byte <= 0xFF
    return HOOK_BASE + HOOK_STRIDE * byte

def _u32(v):
    return list(v.to_bytes(4, "little"))

def _u16(v):
    return list(v.to_bytes(2, "little"))

def _poly(byte, scalar):
    """Wrap a scalar template in the hook-cell shape dispatch shown above."""
    hook, scalar = _u32(hook_addr(byte)), list(scalar)
    assert len(scalar) < 128, "scalar body too long to jump over with a rel8"
    call = [0xFF, 0x14, 0x25] + hook + [0xEB, len(scalar)]   # call [hook]; jmp .done
    # W11-1A: imm16 (66 81 /7 iw), since 0x7FFF does not fit cmp's sign-extended imm8.
    b_tag = [0x66, 0x81, 0x7C, 0x24, 0x06] + _u16(LIST_TAG >> 48)   # cmp word [rsp+6], 0x7FFF  (b: TOS)
    a_tag = [0x66, 0x81, 0x7C, 0x24, 0x0E] + _u16(LIST_TAG >> 48)   # cmp word [rsp+14], 0x7FFF (a)
    fast = (b_tag + [0x74, len(a_tag) + 2]          # je  .call
            + a_tag + [0x75, len(call)]             # jne .scalar
            + call)
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

_ATOM_TPL = {b: tpl for b, _mn, _gl, tpl, _d in ATOMS}
# byte -> replacement template.  build_blob2 emits the override INSTEAD of the
# original record (the compiler's `f` returns the FIRST record for a key, so
# emitting both would be a silent no-op); boot/golfref.py applies the same dict
# LAST over its TEMPLATES (dict update = last wins), so the two agree.
OVERRIDES = {b: _poly(b, v1.TEMPLATES[chr(b)]) for b in map(ord, "+-*")}
OVERRIDES.update({b: _poly(b, _ATOM_TPL[b]) for b in (0x88, 0x89)})  # ⌈ max ⌊ min
# W10-B: v1's UNSIGNED / % (frozen in data/v1.hex as `pop rcx; pop rax;
# xor edx,edx; div rcx; push rax|rdx`, which dies of SIGFPE on b == 0) get the
# same zero check as ÷ ∣.  Unsigned div has no other #DE case, so the tail is
# v1's own and every nonzero divisor gives exactly v1's result.  The frozen
# seed rung (built by v1c) keeps v1's templates; every v2-built binary,
# including the compiler itself, gets these.
def _udivchk(scalar):
    assert scalar[:2] == [0x59, 0x58] and scalar[2:7] == [0x31, 0xD2, 0x48, 0xF7, 0xF1]
    return _DIV0_GUARD + scalar[2:]              # .ok: xor edx,edx; div rcx; push
OVERRIDES.update({b: _udivchk(v1.TEMPLATES[chr(b)]) for b in map(ord, "/%")})
# W11-1C: v1's `.` (exit), `)` (write one byte) and `(` (read one byte) call the
# flush hook first (_FLUSH_CALL, above), so buffered printer output is never
# lost at an explicit exit and never reordered against a raw `)` byte or behind
# a `(` read.  `)` and `(` themselves stay raw and unbuffered — one write(2) or
# read(2) per byte, as in v1.  The end-of-program exit (blob record 5) gets the
# same prefix as AUTOEXIT2.
OVERRIDES.update({b: _FLUSH_CALL + list(v1.TEMPLATES[chr(b)]) for b in map(ord, ".)(")})
# W13-B (S3, implicit output): the end-of-program exit — and ONLY it, not `.`
# — first calls through the END HOOK, the 1C runtime cell 0x4F09A0 (5179808,
# next to the flush hook).  The prelude's init stores the program's base rsp
# and fills the cell with ‹_13b_end›, which prints the one value left above
# that base (⍕ a list, Ṅ anything else) when exactly one is.  Then the flush
# hook drains it.  BSS 0 without the prelude (golfc -n, every compiler
# binary): a load, a test and a not-taken jump, nothing else changes.
END_HOOK = 0x4F09A0
_END_CALL = _hook_call(END_HOOK)
AUTOEXIT2 = bytes(_END_CALL) + bytes(_FLUSH_CALL) + v1.AUTOEXIT

# W12-O1: the unary arithmetic atoms ± ⊕ ⊖ ² ⊗ ⊘ refuse a list.  Before W12
# they computed on its tagged address (`5⍳⊕⍕` printed garbage).  They are the
# hottest ops in a loop, so the int path pays one compare-and-branch and no
# cell load:
#
#     80 7C 24 07 7F            cmp byte [rsp+7], 0x7F   ; TOS's top byte
#     75 0F                     jne .scalar              ; not tag-shaped
#     <_hook_call(NAN_HOOK)>    mov rax,[hook]; test; jz .scalar; call rax
#   .scalar:  <the original atom template, byte for byte>
#
# The filter is the top BYTE, not the top 16 bits: `cmp byte` has no
# length-changing 0x66 prefix, and it is 2 bytes shorter.  It is a superset
# of the tag test (every list has top byte 0x7F), so it is never wrong, only
# loose: ints in [0x7F<<56, 2^63) — INT64_MAX among them — also reach the
# hook.  The hook is EXACT and cheap to leave: the prelude's ‹_12o1_nan›
# returns at once unless the value is tagged (`v>>48 == 0x7FFF`) AND its
# address lies in the list heap [base, base+span) (cells 0x4F0034/0x4F0038,
# A's own), so it never throws on INT64_MAX, on any negative int, or on
# anything the heap cannot hold.  When it does throw, ‹throw› takes it
# (`GOLF: not a number`, catchable).  When it returns, the scalar body runs
# exactly as before, so the hook is stack-neutral like the M-VEC ones.
#
# Off by default, like every hook: the cell is the W12 O1 runtime cell
# 0x4F0DC0 (5180864, REGISTRY.md §3.2), BSS-zero, filled by the prelude's
# init.  A program without the prelude (golfc -n, every compiler binary) never
# calls anything and computes on the bits as it always did.  All six share the
# one cell: they raise the same error.  The bitwise atoms ~ $ | = > ≪ ≫ stay
# RAW (no check): bit operations on a tagged value are how the prelude builds
# and strips the tag in the first place.  The raw arithmetic atoms ﹢ ﹣ ﹡ ⊓ ⊔ ﹤
# are unaffected too.
NAN_HOOK = 0x4F0DC0
_NAN_CALL = _hook_call(NAN_HOOK)
def _numchk(scalar):
    """Prefix a unary atom with the W12-O1 not-a-number check (22 bytes)."""
    tpl = ([0x80, 0x7C, 0x24, 0x07, 0x7F]         # cmp byte [rsp+7], 0x7F
           + [0x75, len(_NAN_CALL)] + _NAN_CALL    # jne .scalar ; hook call
           + list(scalar))
    assert len(tpl) == 22 + len(scalar)
    return tpl
NUMCHK_BYTES = (0x80, 0x81, 0x82, 0x83, 0x84, 0x85)   # ± ⊕ ⊖ ² ⊗ ⊘
OVERRIDES.update({b: _numchk(_ATOM_TPL[b]) for b in NUMCHK_BYTES})

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
LNAME_BYTE = 0xB4   # ‹  opens a long name: ‹name› (M2, W9-3A)
RNAME_BYTE = 0xB5   # ›  closes it
IMPORT_BYTE = 0xB6  # ⎘  ⎘“path“ compiles that file's bytes in place (W11-2A)
# W11-2A's compiler-only memory (../REGISTRY.md §3; layout in self/golf2.golfj):
IMPORT_PATH = 0x438000    # [len:4][path][0]; the len cell becomes `lib/` to retry
IMPORT_FDS = 0x438100     # saved dup() of fd 0 per include level, 4 bytes each
IMPORT_TABLE = 0x438200   # include-once table, 256 bytes per path: [len:4][bytes]
IMPORT_DEPTH = 8          # includes nest at most this deep
IMPORT_FILES = 60         # distinct files one compile may include
IMPORT_LEN = 250          # the longest include path, in bytes
IMPORT_DIRS = (b"", b"lib/", b"vendor/")  # where a path is looked for, in order (vendor/: W11-4A)
REC_BYTE = 0xB7     # ⊜  ⊜‹point›‹x›‹y›; defines constructor/accessors/setters (W11-4A)
# W11-4A's compiler-only memory (../REGISTRY.md §3; layout in self/golf2.golfj):
REC_FIELDS = 0x43C000     # field k's name number at REC_FIELDS + 4*k
REC_MAX = 256             # fields one record may have
VENDOR_PATH = 0x43F000    # the C string `vendor/path` the third include try opens
ELSE_BYTE = 0xB8    # ⋄  the else of c[a⋄b] and the test of {c⋄body} (W12-A7); no memory
VINC_BYTE = 0xB9    # ⇡x  increment variable x in memory, inc qword [cell] (W12-Z2); no memory
VDEC_BYTE = 0xBA    # ⇣x  decrement it, dec qword [cell]; in a ⊡ word a named local wins
# W13-A: S2 inline blocks, ⟦ … ⟧ — an anonymous word compiled in place and
# jumped over; ⟧ pushes its address.  No memory: the compile-time stack holds
# the jmp site, the saved ⊡ flag and the tag 1000005 (see self/golf2.golfj).
BLOCK_BYTE = 0xBB   # ⟦  opens an inline block
ENDBLOCK_BYTE = 0xBC  # ⟧  closes it and pushes its address
# W13-A: S1 adverbs.  A call token (an atom, a v1 arithmetic op, a one-byte
# word, a ‹long name› — and any token that compiles as one, such as a digraph)
# IMMEDIATELY followed by one of these bytes is compiled as `′token` instead
# of a call: `f€` is `′f€`.  Listed ONCE, here: build_blob2() stores the set as
# blob record ADVERB_KEY, which golf2 and the seed scan, and boot/golfref.py
# imports it.  Glyphs, in order: € ⇤ ⌿ ⊞ ⍀ ⍁ ⍸ ⍒ ⊟ ⍣, then W13's ⍂ ⍃ ⍖ ⍷
# (0xE7 0xE8 0xEA 0xEC, prelude words another W13 agent adds).
ADVERBS = bytes([ord("M"), ord("F"), ord("W"), ord("Z"),
                 0xD1, 0xD2, 0xD3, 0xD4, 0xD8, 0xD9,
                 0xE7, 0xE8, 0xEA, 0xEC])
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
UNQUOTED = b'"_\\&@!?,().' + bytes([0xC5, 0xD0, 0xA4, 0xA5])
ADVERB_KEY = 6      # blob record keys: control bytes, never an op, so `f`
UNQUOTED_KEY = 7    # finds these two only when asked by number
DIGRAPH_BYTE = 0xBD # ʘB  W13-B (S6): compiles exactly as the long name ‹_dgHH› (HH = B in upper-case hex); no memory
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

assert v1.STARTUP[0] == 0xBD and len(v1.STARTUP) == 5, "STARTUP is not mov ebp,imm32"
SETUP_RSTACK = bytes([0xBD]) + RSTACK_TOP.to_bytes(4, "little")  # mov ebp, RSTACK_TOP

def _check_atoms():
    """Op-byte namespace (see ../REGISTRY.md §1): an ATOMS byte must be unique
    and must not shadow a compiler prefix or a v1 template byte."""
    bs = [b for b, _mn, _gl, _tpl, _doc in ATOMS]
    dup = sorted({b for b in bs if bs.count(b) > 1})
    assert not dup, "duplicate ATOMS byte: " + ", ".join(f"0x{b:02X}" for b in dup)
    taken = {REF_BYTE, STR_BYTE, SET_BYTE, GET_BYTE, CHAIN_BYTE, FRAME_BYTE,
             LSET_BYTE, LGET_BYTE, LNAME_BYTE, RNAME_BYTE,
             BLOCK_BYTE, ENDBLOCK_BYTE}           # W13-A
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
GUARD_PAGE = (bytes([0x6A, 10, 0x58])                       # push 10; pop rax  (mprotect)
              + bytes([0xBF]) + GUARD_LO.to_bytes(4, "little")  # mov edi, GUARD_LO
              + bytes([0x6A, 0x01, 0x5E])                   # push 1; pop rsi   (len: 1 page)
              + bytes([0x31, 0xD2])                         # xor edx, edx      (PROT_NONE)
              + bytes([0x0F, 0x05]))                        # syscall
assert len(GUARD_PAGE) == 15
STARTUP2 = ARGV_STASH + GUARD_PAGE + SETUP_RSTACK

def build_blob2():
    b = bytearray()
    b += v1.rec(1, v1.PROLOGUE)
    b += v1.rec(2, v1.COND)
    b += v1.rec(3, STARTUP2)                     # M-TOOL stash + W9-2C guard + M-MEM rbp
    b += v1.rec(4, header_pairs2())              # M-MEM: shrunken p_memsz
    b += v1.rec(5, AUTOEXIT2)                    # W11-1C: flush hook, then exit(0)
    b += v1.rec(ADVERB_KEY, ADVERBS)             # W13-A: S1's adverb set
    b += v1.rec(UNQUOTED_KEY, UNQUOTED)          # W13-A: and the ops it never quotes
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
# W11-2A: the seed's syscall.  v1 GOLF has no syscall op, and include needs
# open/dup/dup2/close, so self/seed.golfv1's word K carries one as a raw blob
# escape spliced in at @SYS@: ⎈'s template, then `jmp +5` over the `push imm32`
# the blob escape emits after its data.  The seed's main zeroes the rel32 of
# the escape's own jmp-over once (v1's code segment is RWX), so K falls into
# these bytes from then on.  Replaced in the stripped source, before the
# template blob goes in, so the blob's raw bytes are never searched.
SYS_MARKER = b"@SYS@"
SEED_SYS = bytes(_ATOM_TPL[0xA7]) + bytes([0xEB, 0x05])   # ⎈; jmp +5
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

if __name__ == "__main__":
    main()
