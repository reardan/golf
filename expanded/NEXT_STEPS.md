# Expanded GOLF — next steps

The prioritized queue for the expanded language. [`DESIGN.md`](DESIGN.md) holds
the vision, the bootstrap ladder, the record of what shipped and the known
limits; [`GAPS.md`](GAPS.md) audits the language against Python and Jelly and
proposes deltas to this queue (three defects it found are not yet items here);
this file is the forward plan: what to build next, in what order, and why. Every step keeps the two invariants: `test/run2.sh` stays green **including
the golf2 self-hosting fixpoint**, and `../minimal/` is never touched.

## Where we are

The original roadmap is done. The code page, the atom set, lists on a `brk`-grown
heap, quotations and higher-order words, strings, named variables, a total list
runtime, shape polymorphism, *implicit* vectorization on the bare `+ - * ⌈ ⌊`,
tacit combinators built at runtime, 64-bit values with big literals, and the
compiler's own source migrated to v2 GOLF — all shipped, with `run2.sh` and
`selfcheck.sh` green. Since then: a 64-bit variable bank (M3W) and chain
definitions (M-CHAIN2), the first compiler logic authored in `golf2.golfj` as
the primary source; and M-TOOL, which gave the language syscalls (`⎈`), argv,
three tool libraries on the lowercase letters, and the repo's own build scripts
rewritten in GOLF under `gtools/` — each one gated against its Python twin for
byte-identical output. Most recently M-DIAG, the first two diagnostics the
language has ever had, both found by the [`GAPS.md`](GAPS.md) audit rather than
in use. (The current counts and sizes live in DESIGN.md's table, where the suite
asserts them.)

Four facts about the implementation shape everything below:

1. **Templates dispatch before words.** The compiler tries the template blob
   before the word dictionary, so an atom byte can never be shadowed by a
   prelude definition — which is why making a *bare* operator polymorphic had to
   happen inside its template, and why any future one does too.
2. **The whole load segment is RWX** and a quotation is just an address, so the
   prelude can write machine code at runtime. `∘` already does; anything that
   wants to synthesize a closure can too, with no compiler change.
3. **`T` is a range test, not a tag.** Everything polymorphic rests on "is this
   value inside the heap window", which is cheap, correct for every value the
   suite exercises, and wrong in principle. Item 1 below is the fix — and
   the scheme this file used to specify for it was not.
4. **The compiler binary never runs the prelude**, so its M-VEC hook cells stay
   zero and it always takes the scalar path. That is the reason implicit
   vectorization did not disturb the fixpoint, and the same argument covers any
   future hook.

## The queue

Two items left it since the roadmap closed, both shipped and both recorded in
DESIGN.md: **M3W** (the variable bank is 64 bits per name) and **M-CHAIN2**
(chain definitions). `M-TAG2` moved back rather than forward, because the scheme
it specified turns out to be wrong for a reason worth writing down — it is now
item 1, with the counterexample and a corrected design.

### 1. M-TAG2 — a real tag bit (medium — **the specified scheme is wrong**)

*What.* Retire the range test. `T` is `v - base <u span` today, so an *integer*
that happens to land in `[base, base+span)` is dispatched as a list — the one
outright incorrect behavior in the language (DESIGN.md, known limits). Range
tagging also forces the two 32-bit bounds cells at `0x4F0034`/`0x4F0038`, which
put a hard 4 GB ceiling on the break.

*Why it is also the gate on nested data.* This item used to be sold on
correctness alone, which undersells it. GOLF's list cells hold whatever you put
in them, so a list of lists **stores** fine — but nothing above the storage layer
knows: `⍕` prints inner lists as raw pointers, and M-VEC's five operators
dispatch on the shapes of their two operands exactly once, never recursing into
elements. Jelly's core data structure is the arbitrarily nested list, so this is
the single largest gap to it ([`GAPS.md`](GAPS.md) §1.1). Every fix for it —
a recursive `⍕`, depth, rank, vectorization to arbitrary depth, a structural
`≡` — has to ask "is this cell a list?" of *every element*, which is exactly the
question `T` currently answers with a heuristic that is wrong in principle.
Asking it once per operand is survivable; asking it per element, at every depth,
is not. **The tag bit is the prerequisite for all of it**, and that is a better
reason to do it than the misclassification bug on its own.

*Why the bit-63 plan cannot ship.* This entry used to say: hand the address to
user code with **bit 63** set, and `T` becomes `v >> 63`. That is exact for
pointers and catastrophic for integers — **every negative number has bit 63
set**. `0 1-` is `0xFFFF…FF`, so under that scheme `-1` classifies as a list;
the M-VEC preamble's `or rax,[rsp+8]; jns .scalar` filter would send `-1 5+` to
the dispatcher as list-shaped and `Ṅ` would dereference it. The suite already
pins the opposite (`0 1-T` → int, and "a -1 flag reaches the hook and falls back
to the scalar op"), so the change trades a rare wrong answer for a common one.
GOLF has been signed since M4 — `≺ ≻ ≫`, `÷`, `∣` and `N`'s sign check all say
so — and any tag in the sign bit fights that.

*What a correct version looks like.* The honest framing is that in an untagged
64-bit word you cannot have both the full integer range and an exact pointer
tag; you only choose **which integers you sacrifice**. Ranked:

1. **A high-byte tag, e.g. `v >> 48 == 1`** (list = `addr | 2^48`). Negative
   numbers are `0xFFFF…` at the top and stay integers; so does everything under
   `2^48`. The sacrificed set becomes `[2^48, 2^49)` — 281 to 562 trillion —
   instead of "any number the size of a few megabytes", which is the range real
   programs actually compute in. It keeps every advertised win: `T` is a shift
   and a compare, the two bounds cells and the 4 GB ceiling go away, and the
   M-VEC filter becomes exact. Masking is `(v<<16)>>16` — two atoms, no cell.
2. **Keep the range test, make the window exact.** Cheap, no representation
   change, but it does not fix the known wrong answer at all.
3. **Tag the int (bit 0, Lisp-style).** Every arithmetic template would shift
   and unshift; GOLF's atoms are raw one-instruction templates and that is the
   whole aesthetic. Rejected.

Option 1 is what a future wave should implement. Its prerequisite, M3W, is
shipped: the variable bank is 64 bits per name, so a `2^48` tag survives
`→x`/`←x` — which a 4-byte cell would have truncated off.

*Fixpoint impact.* Same argument as M-VEC: the compiler never runs the prelude,
its hooks stay zero, and both golf2 and golf2' embed the new blob. Real but
contained, and the ladder verifies exactly this.

*Tests.* The regression that cannot pass today — take the heap base out of the
bounds cell, hand it to `+` as an *integer*, and require scalar addition — plus
the one that guards the fix: `0 1-T` is still an int, and so is every negative a
program can produce. Every existing polymorphic test unchanged;
`0x4F0034`/`0x4F0038` deleted from REGISTRY.md §3 in the same commit.

### 2. M-FRAME2 — size the frame per definition (medium)

**M-FRAME shipped** (DESIGN.md): `⊡name … ;` owns a frame of eight slots and
`⇒x`/`⇐x` reach them, so recursion through a local is correct. What it did *not*
do is size the frame, and the reason is the part of the original plan that did
not survive contact with the compiler.

*What went wrong with the sketch.* This entry used to say "give a definition a
prologue that reserves *n* cells below `rbp` and a matching epilogue". Whatever
the prologue does to `rbp` the epilogue must undo — and `^` **is** an epilogue,
is a plain template, and can appear anywhere in a body. A single-pass compiler
does not know *n* until `;`, long after the `^`s were emitted. The sketch also
proposed "a fixed 26-slot frame indexed by the letter", which is 216 bytes a
frame; even at eight slots an unconditional frame is 72 bytes and drops the
return stack from ~138k frames to ~15k, killing run2.sh's 50,000-deep recursion
case. Both were measured, not argued.

*What shipped instead.* Opt-in. `^` became compiler logic, but only to test one
flag, so a `:` word still emits byte-for-byte what it did before and nothing
regressed. The frame is a fixed eight slots, `a`–`h`.

*What is left.* Per-definition sizing, which is strictly the better language: a
word using two locals should pay for two. It needs `⊡` to emit `sub rbp, imm32`
with a patchable immediate, and every `^` in the body to emit `add rbp, imm32`
the same way — many sites per word, so the patch sites have to be threaded as a
linked list through their own unpatched immediates and walked at `;`. That is a
well-understood assembler technique and costs one compiler variable (definitions
do not nest), but it is real work and M-FRAME already removed the wrong answer.

*Also still open.* Eight slots means eight *names*, `a`–`h`; a real symbol table
(M2, item 4) would let a `⊡` word name its locals anything and let the count fall
out of the name arena. And the return stack still has no guard — see DESIGN.md's
known limits, where M-FRAME's ~15k-frame ceiling now makes it easier to reach.

### 3. M-MEM2 — a free list for the allocator (small-medium)

*What.* `A` bump-allocates and nothing is ever freed. Since `M`, `W`, `V`, `Z`,
`K` and `G` each allocate a fresh list per call, a map inside a loop leaks
linearly — the heap grows with `brk` now, so it does not crash, it just climbs.

*How.* Keep the bump pointer as the fast path and give each block a header cell
carrying its size (the length header nearly is one already). Add a `free` word
that threads a released block onto a size-classed free list; `A` checks the
matching class before bumping. A first cut can be one list and exact-fit only —
the allocation pattern here is overwhelmingly "same-size list, over and over".

*Why here.* It is invisible until a program is long-running, and it wants the
tag bit (item 1) first so a header cell can never be mistaken for a value.

### 4. M2 — multi-character identifiers (medium)

*What.* Word names are single bytes and the uppercase prelude pool is down to
`B` and `C` (REGISTRY.md §2). The code page removed the pressure on *operators*,
not on *names*: a user program with a dozen helpers is out of readable letters.

*How.* As always planned: a real tokenizer, a name arena, and two-pass or
forward-declaration handling so mutual recursion needs no pending-char hack.
The high-byte word range `0xC0`–`0xCF` is the stopgap the prelude already uses;
M2 is what makes it unnecessary.

*Why not sooner.* It is the largest single change to the compiler's front end,
and best done when the language has stopped moving under it.

*But it is no longer independent.* This entry used to say "nothing above needs
it", and that is now false. The uppercase pool is down to `B` and `C` — two
letters — and the library is missing, at minimum, sort, concatenate, take/drop,
member, index-of, unique and a structural `≡` ([`GAPS.md`](GAPS.md) §1.3). Item
5 (M6b) needs letters too, for a line reader and a number parser. Two letters do
not cover either list, so **every remaining library item is gated behind this
one** or behind spending the eight high bytes at `0xC8`–`0xCF` on words that
should have had names. That does not automatically move M2 to the front — the
tag bit is still the thing that makes the *language* correct, and it is cheaper —
but "nothing needs it" is no longer the reason to defer it. Sequencing it right
after the tag bit, and before the allocator, is the honest ordering.

### 5. M6b — a number parser and line-oriented input for USER programs (small)

*What.* The syscall half of this item shipped with M-TOOL: `⎈` (`\sys`, `0xA7`)
is the read atom it asked for, and `lib/tio.golfj` already has buffered input,
a slurp and argv, while `lib/ttext.golfj` has the decimal and hex parsers. What
is *not* done is making any of that reachable from an ordinary program:
`lib/t*.golfj` is prepended only by `gtools/build`, for the repo's own tools.

*How.* Decide what a user program should get, then move exactly that into
`lib/prelude.golfj` — most likely a line reader, a decimal parser, and a
split-on-whitespace yielding a list. The cost is the constraint the tool
libraries were invented to dodge: the prelude's uppercase pool is down to `B`
and `C`, so anything that moves needs a high byte from `0xC8`–`0xCF`, and the
prelude may never use `→x`/`←x` (the bank is user space). Do not simply prepend
`lib/t*.golfj` to user programs — it claims lowercase `a`–`z` wholesale and
would shadow half of any program's own words.

*Tests.* Pipe `1 2 3` in, sum it, print `6`; empty input yields the empty list.

## As needed

- **M7 — compiler quality.** A peephole optimizer still does not fit the
  single-pass backpatch model: any *size-reducing* fold shifts every later rel32
  offset (needs a relocation pass), and a size-preserving one is perf-only. The
  real win is a register-based (top-of-stack-in-a-register) codegen, and it
  wants the relocation pass first.
- **M9 — reach.** `include`/modules; an object-file emitter so output links with
  `cc`; a small IR to retarget (arm64) or emit C.
- **Shape checks.** `Z` truncates to the shorter list and nothing reports a rank
  mismatch. With a real tag (item 1) `D` can afford to say so.

## Hygiene along the way

- Every new atom lands in `tools/mkblob2.py` *and* `boot/golfref.py` (oracle
  parity), with a `tools/codepage.py` row, a `REGISTRY.md` row allocated
  **first**, and a `test/run2.sh` case.
- New *compiler logic* goes in `self/golf2.golfj` **and** `mkblob2.py`'s v1-GOLF
  seed, then `python3 tools/mkblob2.py` and commit the regenerated
  `self/*.golf` — `test/selfcheck.sh` fails if the committed files are not what
  the tool emits, or if the two source forms stop agreeing byte for byte.
- Keep printing the seed size in `run2.sh`; creeping growth is a smell in a golf
  language.
- Each milestone ships with a one-line example in `examples/`, and the capstone
  should keep getting shorter as notation lands. When a spelling stops being the
  shortest way, it does not get deleted — `examples/legacy_capstone.golfj` is
  the pattern: keep it compiled and output-checked.
- **The docs are asserted.** `run2.sh`'s `W7A` block checks the numbers quoted
  in `README.md` and `DESIGN.md` against the artifacts they describe. If a
  change moves one of them, the suite tells you which doc to edit.

## The wave just landed

**M-FRAME — per-call locals, opt in.** The worst remaining defect in the
language: `→x` inside recursion returned a quietly wrong number, and now `⊡` +
`⇒x`/`⇐x` do not. Its design changed under implementation — see item 2 above,
which is now about what M-FRAME *deferred* rather than about locals themselves.
The one-line version: `^` is a template that ends a word, so a single-pass
compiler cannot size a frame per definition, and an unconditional frame costs the
suite's 50,000-deep recursion. Opt-in was the only shape that added the feature
without regressing something already tested.

**M-DIAG — the audit's two fixes.** [`GAPS.md`](GAPS.md) measured the language
against Python and Jelly and turned up three defects nothing in the repo
recorded; two of them were small enough to fix in the same pass. The compose
arena is now bounded (it was silently overwriting the user variable bank after
1680 composes, exit status 0), and an undefined word is now reported instead of
compiling to a jump through a zeroed dictionary slot. Both are in DESIGN.md's
record. The third — nested lists having no support above the storage layer — is
item 1's second justification above, because the tag bit is its prerequisite.

Two things that wave did **not** do. The `′` path still reads an undefined name
as an atom (`X`'s auto-wrapping cannot tell a typo from `′⊗`), which is a
separate small fix. And no diagnostic gained a source position: the compiler is
single-pass with no notion of a line, so "undefined word `b`" is the whole
message it can afford — see DESIGN.md's non-goals.

## Earlier waves

**M3W then M-CHAIN2.** Both lived entirely in the compiler's front end
(`self/golf2.golfj`, `mkblob2.py`'s v1-GOLF seed cases, `boot/golfref.py`) and
neither touched a representation, so they composed: the bank widening went first
because every later tag scheme depends on it, and the chain sugar landed on top.
`run2.sh` is 273 green, `selfcheck.sh` 32, the fixpoint intact.

The tag bit was *not* in that wave. It was the better engineering right up until
the specified scheme turned out to misclassify every negative integer; it went
back on the queue with a corrected design rather than shipping a regression, and
it is now item 1. Items 3 and the shape checks stay behind it, as they always
were.

**M-TOOL landed.** The build scripts rewritten in expanded GOLF are shipped:
`0xA7 ⎈ \sys`, the entry-`rsp` cell at `0x4F0040`, the lowercase library letters
`a`–`z`, and `gtools/`. It ran as a parallel wave against the compiler front-end
work above and the two never contended — the only shared file was
`tools/mkblob2.py`, where they edited different halves (the `ATOMS` table versus
the spliced compiler cases). The one real collision was semantic rather than
textual: M3W widened the variable bank while M-TOOL was documenting the old
4-byte truncation as a hazard, which turned three pieces of prose into history
and one test into a regression case.

What it deliberately did **not** do, and why it should stay that way:
`mkblob2.build_seed()` remains Python. It reuses `minimal/tools/mkblob.py`'s
`WORDS` — the v1 compiler's own source text — and its `golf()` substring-rewrite
pass, so a GOLF port would have to carry a second copy of source that lives in
the frozen tree. And the GOLF tools **shadow** rather than replace: `tools/*.py`
is still the build path, so the repo stays buildable from Python alone and
`test/gtools.sh` is what makes the GOLF side trustworthy.
