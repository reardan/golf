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
2. **A terse golf surface** (Jelly-flavored), via a **code page**: operators are
   single bytes from the full 0..255 space, each shown as a glyph. The minimal
   ASCII language stays valid underneath (bytes 0..127); the golf atoms live at
   0x80+. This is now the active direction — see "Code page" below.

Bytes 128..255 were entirely unused and the compiler's `e` word already
dispatches *any* byte it finds in the template blob, so the code page costs
almost nothing on the compiler side. It is a better answer to "GOLF ran out of
single-byte op slots" than multi-character identifiers, and it leans into the
golf heritage. Multi-char identifiers (M2, below) are now *optional* — useful for
readable user-defined names, but no longer required to grow the built-in op set.

## Code page (Jelly-style)

Like Jelly, the canonical program form is raw bytes, one byte per operation, and
humans read/write them through a code page. `tools/mkblob2.py` is the single
source of truth: each atom has a byte, a display glyph, an ASCII mnemonic, and a
machine-code template. `tools/codepage.py` converts between forms:

```
codepage.py encode <prog.golfj >prog.gb   # \sqr / glyph / ASCII  ->  raw bytes
codepage.py decode <prog.gb               # raw bytes  ->  glyphs (3² 4⊕ …)
codepage.py decode -m <prog.gb            # raw bytes  ->  ASCII \mnemonic form
codepage.py table                         # the atom reference
```

Author in ASCII with `\`-mnemonics (`3\sqr` = "3 squared"), store as raw bytes,
compile with `golf2`. The round-trip is exact. First atoms: `± neg`, `⊕ inc`,
`⊖ dec`, `² sqr`, `⊗ dbl`, `⊘ hlv`, plus the M1 bitwise/shift ops.

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
ASCII single-byte slots. GOLF has now spent its entire *printable* one-glyph
namespace — which is what pushed us to the **code page**: use the whole 0..255
byte space for single-byte ops (bytes 0x80+ for the new atoms) and render them
through glyphs. That keeps GOLF terse and Jelly-like instead of forcing
multi-character identifiers.

## Milestones

Each milestone is independently testable and must keep `test/run2.sh` green
(including the golf2 fixpoint).

- **M1 — new operators (done).** `$ | = ~ >` bitwise/shift ops as templates.
  Backward compatible; golf2 still compiles every v1 program.

- **M-CP — code page (done).** All-256-byte op space + code-page tooling
  (`tools/codepage.py`) + 17 atoms: `± ⊕ ⊖ ² ⊗ ⊘` and the comparison/selection
  family `» ≡ ⌈ ⌊ ÷ ∣` plus the M1 bitwise/shift ops. Each is a single-byte
  machine-code template; `e` dispatches them with no compiler change.

- **M-LIST — list type + standard library, first cut (done).** A list is a heap
  block `[len, e0, e1, …]` of 32-bit cells. Delivered as a **prelude library**
  written in GOLF (`lib/prelude.golfj`, prepended by `tools/golfc`): `A` alloc,
  `R` range, `L` len, `I` index, `S` sum, `N` print-decimal, `E` newline, plus
  the higher-order ops below. The compiler's fixpoint is untouched — the prelude
  is just source that gets prepended. Code-page glyph aliases: `⍳ ∑ ≢ ⊇ ⍶ Ṅ ␤`.
  So `100⍳∑Ṅ` = 4950. Reserved runtime memory: heap pointer at `0x4F0000`,
  scratch at `0x4F0010`.., heap from `0x500000`. Known gap: empty-list handling
  in the `{…}` do-while folds.

- **M-HOF — quotations + higher-order functions (done).** Two primitives:
  `′name` (glyph `′`, byte 0x8C) is a compiler prefix that pushes a word's
  runtime address; `⍎` (`\exec`, byte 0x8D) pops an address and calls it. `′` is
  the first change to golf2's compiler logic vs v1 — a new case in `t`, written
  in v1 GOLF, and golf2's own source never uses it so the strict fixpoint still
  holds. With these, the prelude adds `M` map (`list fn->list`), `F` fold
  (`list init fn->x`), and `Q` print-list. Example: `:d⊗;5⍳′dM∑Ṅ` = "map double
  over range(5), sum" = 20. (Note: `′`/`⍎` take *word* addresses, so to map an
  atom you wrap it, `:d⊗;`.) The code-page `\` escape now also accepts `\\` for a
  literal backslash, since `\` is GOLF's swap op.

- **M2 — multi-character identifiers (optional / parallel).** No longer required
  for op growth, but still valuable for readable *user-defined* names: a real
  tokenizer, a name-arena symbol table, and two-pass/forward-declaration handling
  so mutual recursion needs no pending-char hack. Pursue if/when programs get big
  enough that single-byte word names hurt.

- **M-JELLY — deeper Jelly semantics (Path-A frontier).** The list type, code
  page, and higher-order ops are the surface; the real Jelly power is the model
  underneath: atoms that *vectorize* over lists automatically, and chains
  (implicit argument threading with monadic/dyadic links). Both need runtime
  type tags (int vs list) so a single atom can dispatch on shape — with tags,
  `′`/`⍎` and `M`/`F` become the machinery chains are built from. This is the
  large remaining effort between "GOLF with lists and glyphs" and "an actual golf
  language".

- **M3 — locals & parameters.** Named function arguments and local variables via a
  call frame on the return stack. Removes ~90% of the stack-juggling that makes
  v1 programs hard to write, and shrinks the compiler's own source dramatically.

- **M4 — 64-bit + signed + full arithmetic.** Widen cells from 32 to 64 bits;
  add signed division/modulo (`cqo; idiv`), signed comparison, and shift-left.
  Update the memory cell ops (`@`/`!`) and literals accordingly.

- **M5 — data & strings.** First-class string literals, a data section for named
  globals (not hardcoded addresses), and a small allocator (`brk`/`mmap`).

- **M6 — standard library (in GOLF/2).** Started by `lib/prelude.golf`. Grow it:
  number parse, string ops, more list ops (reverse, map/fold once quotations
  exist), buffered I/O — written in the expanded language, not baked into
  templates.

- **M7 — compiler quality.** A peephole optimizer (fold `push;pop`, dead moves),
  and keeping the top-of-stack in a register instead of always spilling to memory.
  Large output-size and speed win; the first place golf2 stops being a naive
  template concatenator.

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
| `tools/mkblob2.py` | builds golf2.golf: v1 code + atom table (source of truth for atoms) |
| `tools/codepage.py` | code page: encode/decode glyph/mnemonic ⇄ raw bytes; `table` reference |
| `tools/golfc` | compile a program (prepends the prelude; `-j` to encode glyph source) |
| `lib/prelude.golfj` | the standard library: list runtime, map/fold, number/list printing |
| `boot/golfref.py` | Python reference/oracle for v2 (debugging only) |
| `examples/` | v2 programs (`bitwise.g2`, `atoms.golfj`, `lists.golfj`, …) |
| `test/run2.sh` | bootstrap ladder + atom + code-page + list tests |
