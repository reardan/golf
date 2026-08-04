# Expanded GOLF (v2) — design & roadmap

This is the evolving, "fully featured" version of GOLF. The minimal 760-byte
self-hosting compiler is frozen in `../minimal/` (tag `v1.0-minimal`); nothing
here changes it. The goal here is a language you'd actually write real programs
in, grown one testable milestone at a time while **never breaking the
self-hosting bootstrap**.

## Vision: hybrid

Two useful languages hide inside GOLF:

1. **A usable minimal language** (Forth/C-flavored): multi-character names,
   locals & parameters, signed 64-bit values, a small standard library. The core
   you can write programs — and the rest of the compiler — in.
2. **A terse golf surface** (Jelly-flavored), via a **code page**: operators are
   single bytes from the full 0..255 space, each shown as a glyph. The minimal
   ASCII language stays valid underneath (bytes 0..127); the golf atoms live at
   0x80+. See "Code page" below.

The plan was (1) then (2); what actually happened was (2) then most of (1). The
code page removed the pressure that multi-character names were supposed to
relieve, so the golf surface, the library and 64-bit values came first, and the
two pieces of (1) still outstanding — real names and per-call locals — are items
6 and 4 of [`NEXT_STEPS.md`](NEXT_STEPS.md).

Bytes 128..255 were entirely unused and the compiler's `e` word already
dispatches *any* byte it finds in the template blob, so the code page costs
almost nothing on the compiler side. It is a better answer to "GOLF ran out of
single-byte op slots" than multi-character identifiers, and it leans into the
golf heritage. Multi-char identifiers (M2, now in [`NEXT_STEPS.md`](NEXT_STEPS.md))
are *optional* — useful for readable user-defined names, but no longer required
to grow the built-in op set.

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
compiler that can build the current source, and the bootstrap reaches a
byte-identical fixpoint.** The chain is:

```
golf0.py  --compiles-->  v1c      # the frozen minimal compiler (../minimal)
v1c       --compiles-->  seed     # self/seed.golf,  compiler logic in v1 GOLF
seed      --compiles-->  golf2    # self/golf2.golf, compiler logic in v2 GOLF
golf2     --compiles-->  golf2'   # same source — require golf2 == golf2'
golf2'    --compiles-->  your v2 programs
```

**Since M-SELF the compiler's logic is written in v2 GOLF.** The source a human
edits is `self/golf2.golfj` — named variables (`→x` / `←x`), one op per line,
every op explained — instead of v1's single-char stack juggling. The last rung is
therefore a *true* self-hosting fixpoint: golf2 compiles its own source back to
itself, byte for byte, in the richer language it grew.

The gate is **golf2 == golf2'**. Both are built from `self/golf2.golf`, so they
embed the same template blob and emit the same code for the same source: the
self-hosted compiler has already converged at iterate 1.

`self/seed.golf` is the **bootstrap rung and nothing more**. It carries the same
compiler written in v1 GOLF (v1's `mkblob.WORDS` plus the four spliced compiler
cases `′ “ → ←`), purely so `v1c` — which has never heard of v2 — can build
something able to compile `golf2.golf`. Because v1c embeds *v1's* blob it emits
different bytes than golf2 would, but **that divergence is absorbed at the
v1c→seed rung**: `seed` is only ever used to produce golf2 and is never compared
against anything. (Before M-SELF this showed up as the `seed-stable:`
informational line; there is nothing left to report, so it is retired.)

Two sources for one compiler is a real risk of drift, so `test/selfcheck.sh`
gates what the ladder cannot see: that `seed` and `golf2` emit **byte-identical
binaries for every input** — they are the same compiler written twice, in two
languages — and that the generated `self/*.golf` are exactly what
`tools/mkblob2.py` emits from `self/golf2.golfj`.

The standing rule is unchanged: golf2's **source must always be compilable by
the current toolchain.** That toolchain is now `seed`, so `golf2.golfj` may use
only ASCII plus the ops the seed implements (the four compiler prefixes and the
atom bytes) — `selfcheck.sh` enforces exactly that. The seed stays as small as
possible: just enough to make the real compiler pleasant to write. New compiler
features go in `golf2.golfj`; `seed.golf` is frozen in shape.

**Reference oracle.** `boot/golfref.py` is v1's Python reference plus v2's new
op templates. It is not on the bootstrap path — it's a debugging oracle to
cross-check the self-hosted `golf2` while a milestone is in flux.

Run everything: `bash test/run2.sh`.

## Where things stand

Every number in this table is asserted by the `W7A` block of `test/run2.sh`
against the thing it describes, so none of it can go stale quietly.

| Measured | Now |
|----------|-----|
| operator atoms in `mkblob2.ATOMS` | **32** |
| the template blob itself | **714** bytes |
| the generated bootstrap seed (`self/seed.golf`) | **1680** bytes |
| the generated v2 compiler (`self/golf2.golf`) | **4523** bytes |
| assertions in the run2 suite | **273** |
| assertions in the selfcheck suite | **32** |
| the capstone, in op bytes | **46** |
| the legacy capstone, in op bytes | **54** |
| the v2 p_memsz (`mkblob2.MEMSZ`) | **0x200000** |
| the return-stack top address (`mkblob2.RSTACK_TOP`) | **0x600000** |
| clean return-stack frames | ≈**138**k |

The roadmap that this file used to carry as a plan is now history; the forward
queue lives in [`NEXT_STEPS.md`](NEXT_STEPS.md).

## The record: what shipped

Each milestone was independently testable and had to keep `test/run2.sh` green,
the golf2 fixpoint included. In order:

- **M1 — new operators.** `$ | = ~ >` (AND, OR, XOR, NOT, SHR) as pure templates:
  the compiler's `e` word dispatches *any* byte it finds in the blob, so a "dumb"
  op costs its template and zero compiler-logic change. It also spent the **last**
  five free printable ASCII slots — which is what forced the code page.
- **M-CP — the code page.** The whole 0..255 byte space for ops, rendered through
  glyphs, plus `tools/codepage.py` (encode/decode/table/check). Terse and
  Jelly-like, instead of multi-character identifiers.
- **M-LIST — the list type and a prelude.** A list is a heap block
  `[len, e0, e1, …]`; the library is written in GOLF (`lib/prelude.golfj`,
  prepended by `tools/golfc`), so the compiler's fixpoint never notices it.
- **M-HOF — quotations.** `′name` (compiler prefix) pushes a word's runtime
  address, `⍎` calls one. The first change to golf2's logic vs v1 — and with it
  `map`, `fold`, `filter`, `zip` are ordinary library words.
- **M5 — strings.** `“...“` emits a length-prefixed byte block; `U` turns one
  into a list of char codes, so every list op works on text, and `J` prints a
  code list back.
- **M3 — named variables.** `→x` / `←x` over a name-indexed **global** bank at
  `0x4E0000`: `(a+b)*(a-b)` is `←a←b+←a←b-*`. Global, not per-frame (see limits).
- **M-SOUND — a total list runtime.** Every prelude loop is guarded, so the empty
  list is a fixed point rather than garbage, and `Z` truncates to the shorter of
  its two inputs instead of reading off the end.
- **M-TAG — shape polymorphism as a library.** `T` answers "list or int" by range
  (`v - base <u span` against the runtime heap-bounds cells), `D` dispatches a
  binary op on the shapes of both operands, and `∔ ∸ ⨰ ⩍ ⩌` are the polymorphic
  arithmetic words built on it.
- **M-VEC — the bare operators vectorize.** `4⍳3+` is `3 4 5 6`, `4⍳4⍳*∑` is a
  dot product, with no type tag on the value and no change to the compiler's
  logic. Each of `+ - * ⌈ ⌊` keeps its scalar body and gains a 38-byte preamble:
  `cmp qword [hook],0; je scalar` (hook table: 256 cells of 8 bytes at `0x4F0100`,
  indexed by op byte — REGISTRY.md §3), then a conservative `(a|b) <u heap-base`
  filter, then `call qword [hook]`. **The prelude is authoritative, not the
  filter:** the hooks point at `∔ ∸ ⨰ ⩌ ⩍`, whose dispatcher re-tests both
  operands with `T` and falls back to the raw scalar op — so a `-1` flag from
  `<`, which the cheap filter cannot reject, is still added, not indexed. The
  prelude's own pointer math uses the never-polymorphic raw atoms
  `﹢ ﹣ ﹡ ⊓ ⊔` (0x91–0x96), so nothing recurses. **Why the bootstrap survives
  it:** the hook cells are BSS and no compiler on the ladder ever runs the
  prelude, so its cells stay zero and it always takes the scalar path.
- **M-CHAIN — tacit combinators.** `∘` compose writes a 39-byte thunk into the
  RWX code arena at `0x4D0000` and returns its address, so composed quotations
  are ordinary callables; `⇉` pipeline and `⑂` fork are built on it —
  `5⍳′∑′≢′÷⑂` is a mean. Library only, no compiler change.
- **M4 — 64 bits, signed, big literals.** List cells and the prelude scratch bank
  widened to 8 bytes (the bank was *relocated* to `0x4F0060` rather than widened
  in place); signed compare/shift atoms (`≺ ≻ ≪ ≫`) and 64-bit `⊙`/`⊛` landed;
  `Ṅ` grew a sign check; and the compiler's `W` word gained a
  `mov rax,imm64; push rax` path for constants that `push imm32` cannot carry.
- **M-SELF — the compiler's source moved to v2 GOLF.** The ladder grew its last
  rung and `self/golf2.golfj` became the file a human edits; `self/seed.golf` was
  demoted to a bootstrap rung, and `test/selfcheck.sh` began gating that the two
  are one compiler.
- **M-MEM — the heap belongs to the kernel.** `⌸` (`brk`, 0xA6) grows the list
  heap on demand, so v2 binaries reserve only what is *statically* addressed:
  `p_memsz` shrank from `0x800000` to `0x200000`, the return stack moved with it
  to `0x600000`, and the heap base/span moved into the runtime cells at
  `0x4F0034`/`0x4F0038` because ASLR means they cannot be spelled out anywhere.
- **M-CHAIN2 — chain definitions.** `⊚name f g h;` (byte `0xB0`) defines a word
  as a *train of links* and lets the compiler supply every `′`: how many links
  there are decides the shape — one is a call, two are two calls, three are
  `′f ′g ′h ⑂`, more are the fork then the rest in turn — so `⊚m∑≢÷;` compiles to
  byte-for-byte what `:m′∑′≢′÷⑂;` compiles to. The count is the whole mechanism:
  only the first three link bytes are buffered, so there is no driver word, no
  new prelude state and no runtime list of quotations. The `′` case's body moved
  into the shared word `X` ("push the address of the word or atom named by this
  byte"), which the chain calls three times. First new compiler logic since
  M-SELF, and the first written in `self/golf2.golfj` as the primary source.
- **M3W — the variable bank goes 64-bit.** The last narrow place on the value
  path: `→x`/`←x` went through a 4-byte-per-name bank and `←x` was a `mov eax`,
  so `4294967296→x←x` was `0` and `0 5-→x←x` was `4294967291`. Stride 4 → 8 plus
  a REX.W on both emitters — in `self/golf2.golfj`, `mkblob2.py`'s v1-GOLF seed
  cases and `boot/golfref.py`, which `selfcheck.sh` gates for drift. 256 names ×
  8 bytes = 2 KB, still inside the `0x4E0000`–`0x4F0000` hole, so no address was
  reallocated. **Every value a GOLF program can hold is now 64 bits wide
  everywhere it can sit.**
- **The capstone shrank.** `examples/capstone.golfj` went from **54** op bytes to
  **46** by letting the bare polymorphic operators do the looping; the pre-M-VEC
  spellings are kept verbatim and output-checked as
  `examples/legacy_capstone.golfj`, because they are still how a list meets a
  function that is not one of the five hooked operators.

## Invariants we do not break

- `test/run2.sh` stays green, **including the golf2 self-hosting fixpoint**
  (`golf2 == golf2'`), at every commit.
- `../minimal/` is never touched; it remains the ground-truth bootstrap root.
- `self/golf2.golf` and `self/seed.golf` are **generated** — never hand-edited.
  Run `python3 tools/mkblob2.py` from `expanded/` and commit the result;
  `test/selfcheck.sh` fails if what is committed is not what it emits.
- A change to the compiler's logic goes in `self/golf2.golfj` **and** in
  `tools/mkblob2.py`'s v1-GOLF seed, or `test/selfcheck.sh`'s byte-for-byte
  `seed == golf2` comparison catches the drift.
- Every new "dumb" op is added as a template in `tools/mkblob2.py` (and mirrored
  in `boot/golfref.py`), so the reference oracle and the self-hosted compiler
  always agree.
- Every byte, glyph, mnemonic, prelude letter and fixed address is allocated in
  [`REGISTRY.md`](REGISTRY.md) **before** it is implemented, and
  `python3 tools/codepage.py check` enforces the namespace invariants.
- The prelude never uses `→x` / `←x`: the variable bank is user space, so a
  prelude word that stored to `→i` would clobber a user's `i`.
- The numbers quoted in this file and in the top-level `README.md` are asserted
  by `test/run2.sh` against what they describe. Change the thing, change the doc,
  or the suite fails.

## Known limits

These are real, currently true, and none of them is a bug in the bootstrap. The
fixes are queued in [`NEXT_STEPS.md`](NEXT_STEPS.md).

- **The heap-bounds cells are 32-bit too.** `0x4F0034`/`0x4F0038` are read by
  `T` and are baked into all five M-VEC templates as a 32-bit compare operand.
  The break is ASLR-shifted but far below 4 GB in practice; a program that grew
  the break past `2^32` would need those cells — and the templates — widened.
- **`seed` and `golf2` genuinely diverge above `2^31`.** The frozen v1-GOLF seed
  emits `push imm32` for every literal; golf2's `W` word switched to
  `mov rax,imm64; push rax` at `v >> 31`. So the two compilers produce different
  (and, for the seed, *wrong*) bytes for a source containing a literal ≥ `2^31`.
  This is harmless — `self/golf2.golfj` contains no such literal, every address
  it names is under `0x600000`, and the seed's only job is to build golf2 once —
  but it is a genuine property of the ladder, not an oversight.
  `test/selfcheck.sh` proves seed ≡ golf2 on the sources that matter.
- **The return stack is smaller than it was, and better.** M-MEM shrank
  `p_memsz` to `0x200000`, so the stack now runs from `0x600000` down to the
  `0x4F` bank: about 1.08 MB, ≈**138**k frames, all of them *its own*. Before,
  it nominally had ~917k frames but shared them with a bump heap growing up from
  `0x500000` — every 8 bytes allocated cost a frame, and the two met without
  complaint. Deterministic and smaller beats large and shared.
- **KNOWN ISSUE — an integer inside the heap window looks like a list.** `T` is
  a range test (`v - base <u span`), so any *integer* whose value happens to
  land in `[base, base+span)` is dispatched as a list by `D` and by the five
  polymorphic templates. Pre-existing since M-TAG, unfixed, and it moved rather
  than went away when M-MEM put the heap at the break. Known-safe values are
  covered — a `-1` compare flag, a word address, an `0x4D0000` thunk are all
  outside the window and are regression-tested — but nothing rules out a program
  whose arithmetic genuinely produces a heap-sized number. The fix is a real tag
  bit on the value, which is item 3 of the forward queue — where the
  originally specified scheme (bit 63) is now recorded as wrong, because every
  negative integer has that bit set.

## Layout

| Path | What |
|------|------|
| `self/golf2.golfj` | **the v2 compiler's source** — its logic, written in v2 GOLF (edit this) |
| `self/golf2.golf` | GENERATED: `golf2.golfj` code-page encoded + the template blob |
| `self/seed.golf` | GENERATED: the same compiler in v1 GOLF — the bootstrap rung only |
| `tools/mkblob2.py` | builds both `self/*.golf`; source of truth for the atom table + the v1 seed |
| `tools/codepage.py` | code page: encode/decode glyph/mnemonic ⇄ raw bytes; `table` reference |
| `tools/golfc` | compile a program (prepends the prelude; `-j` to encode glyph source) |
| `lib/prelude.golfj` | the standard library: list runtime, map/fold, number/list printing |
| `boot/golfref.py` | Python reference/oracle for v2 (debugging only) |
| `examples/` | v2 programs (`capstone.golfj`, `legacy_capstone.golfj`, `bigheap.golfj`, …) |
| `test/run2.sh` | bootstrap ladder, language tests, oracle differentials, doc assertions |
| `test/selfcheck.sh` | M-SELF: `seed` and `golf2` are the same compiler; the generated files are fresh |
| `REGISTRY.md` | the allocation ledger: op bytes, mnemonics, glyphs, prelude letters, memory |
| `NEXT_STEPS.md` | the forward queue |
