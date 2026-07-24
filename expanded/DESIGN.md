# Expanded GOLF (v2) — design & roadmap

This is the evolving, "fully featured" version of GOLF. The minimal 760-byte
self-hosting compiler is frozen in `../minimal/` (tag `v1.0-minimal`); nothing
here changes it. The goal here is a language you'd actually write real programs
in, grown one testable milestone at a time while **never breaking the
self-hosting bootstrap**.

## Vision: hybrid

Two useful languages hide inside GOLF, and we build them in order:

1. **A usable minimal language first** (Forth/C-flavored): multi-character names,
   locals & parameters, signed 64-bit values, a small standard library. The core
   you can write programs — and the rest of the compiler — in.
2. **A terse golf surface later** (Jelly-flavored), layered on top of that core as
   sugar: single-glyph aliases, implicit iteration, list ops. The minimal
   language stays available underneath; the golf surface just compiles down to it.

## The bootstrap ladder (how v2 gets built)

We keep the property that makes this project worth doing: **there is always a
compiler that can build the current source, and the three-stage bootstrap is
byte-identical.** The chain is:

```
golf0.py  --compiles-->  v1c        # the frozen minimal compiler (../minimal)
v1c       --compiles-->  golf2      # self/golf2.golf, written in v1 GOLF
golf2     --compiles-->  golf2'     # require golf2 == golf2'  (fixpoint)
golf2     --compiles-->  your v2 programs
```

`self/golf2.golf` is the v2 compiler. Its **source must always be compilable by
the current toolchain.** Today that toolchain is `v1c`, so golf2's code is still
plain v1 GOLF and is, in fact, byte-identical to v1's compiler — only the
embedded template table has grown. As soon as golf2 gains a feature that makes it
easier to write (multi-char names, locals), we migrate golf2's *own* source to
use that feature; from then on golf2 compiles itself and the ladder's last rung
becomes a true self-hosting fixpoint on the richer language.

So only the *seed* is written in painful single-char GOLF, and we keep that seed
as small as possible: just enough to make the real compiler pleasant to write.

**Reference oracle.** `boot/golfref.py` is v1's Python reference plus v2's new
op templates. It is not on the bootstrap path — it's a debugging oracle to
cross-check the self-hosted `golf2` while a milestone is in flux.

Run everything: `bash test/run2.sh`.

## Why "more ops" was the natural first step — and what it forces

Milestone 1 adds five operators (`$` AND, `|` OR, `=` XOR, `~` NOT, `>` SHR). In
GOLF a "dumb" op is compiled by copying a fixed machine-code template, and the
compiler's `e` word already dispatches *any* op it finds in the template blob —
so a new dumb op costs **only its template, zero compiler-logic change**. That is
why this was the cheapest possible first feature and why it exercises the whole
ladder without touching golf2's code.

It also hits a wall on purpose: those five chars were the **last** free printable
ASCII single-byte slots. GOLF has now spent its entire one-glyph namespace. The
only way to add more operations, and the only way to have readable names, is
**multi-character identifiers** — which is exactly Milestone 2.

## Milestones

Each milestone is independently testable and must keep `test/run2.sh` green
(including the golf2 fixpoint).

- **M1 — new operators (done).** `$ | = ~ >` bitwise/shift ops as templates.
  Backward compatible; golf2 still compiles every v1 program.

- **M2 — multi-character identifiers.** The big one. A real tokenizer (identifiers
  vs numbers vs op glyphs), a symbol table keyed by name (a name arena + linear
  or hashed lookup instead of the 256-slot array), and two-pass or
  forward-declaration handling so mutual recursion needs no pending-char hack.
  This is where golf2's source starts using names and begins self-hosting on the
  richer language.

- **M3 — locals & parameters.** Named function arguments and local variables via a
  call frame on the return stack. Removes ~90% of the stack-juggling that makes
  v1 programs hard to write, and shrinks the compiler's own source dramatically.

- **M4 — 64-bit + signed + full arithmetic.** Widen cells from 32 to 64 bits;
  add signed division/modulo (`cqo; idiv`), signed comparison, and shift-left.
  Update the memory cell ops (`@`/`!`) and literals accordingly.

- **M5 — data & strings.** First-class string literals, a data section for named
  globals (not hardcoded addresses), and a small allocator (`brk`/`mmap`).

- **M6 — standard library (in GOLF/2).** Number print/parse, string ops, buffered
  I/O — written in the expanded language, not baked into templates.

- **M7 — compiler quality.** A peephole optimizer (fold `push;pop`, dead moves),
  and keeping the top-of-stack in a register instead of always spilling to memory.
  Large output-size and speed win; the first place golf2 stops being a naive
  template concatenator.

- **M8 — golf surface (the hybrid payoff).** A terse alias/sugar layer that
  compiles down to the M2–M6 core: single-glyph names, implicit iteration, list
  ops. The minimal language remains the substrate.

- **M9 — reach (optional).** `include`/modules; an object-file emitter so output
  can be linked with `cc`; a small IR to retarget (arm64) or emit C.

## Invariants we do not break

- `test/run2.sh` stays green, **including the golf2 self-hosting fixpoint**, at
  every commit.
- `../minimal/` is never touched; it remains the ground-truth bootstrap root.
- Every new "dumb" op is added as a template in `tools/mkblob2.py` (and mirrored
  in `boot/golfref.py`), so the reference oracle and the self-hosted compiler
  always agree.

## Layout

| Path | What |
|------|------|
| `self/golf2.golf` | the v2 compiler (generated by `tools/mkblob2.py`) |
| `tools/mkblob2.py` | builds golf2.golf: v1 code + extended template table |
| `boot/golfref.py` | Python reference/oracle for v2 (debugging only) |
| `examples/` | v2 programs (`bitwise.g2`, …) |
| `test/run2.sh` | bootstrap ladder + feature tests |
