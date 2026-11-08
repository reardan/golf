# Expanded GOLF — next steps

The prioritized queue for the expanded language. [`DESIGN.md`](DESIGN.md) holds
the vision, the bootstrap ladder, the record of what shipped and the known
limits; [`GAPS.md`](GAPS.md) audits the language against Python and Jelly and
proposes deltas to this queue (three defects it found are not yet items here);
this file is the forward plan: what to build next, in what order, and why. Every step keeps the two invariants: `test/run2.sh` stays green **including
the golf2 self-hosting fixpoint**, and the frozen v1 substrate (`data/v1.hex`,
the `v1c` binary pinned by `../SEEDS`) is never touched.

## Where we are

**W11 — the Python/Rust gap round — has landed** (four waves, sixteen tasks;
[`GAPS.md`](GAPS.md) "After W11" has the per-area summary). Correctness and
I/O: the list tag moved to the top-16 value `0x7FFF`, file words, an 8 KB
output buffer, text words, and a 192 KB program cap that is checked. Data and
modules: `⎘“path“` includes (cwd, `lib/`, `vendor/`), dicts and sets, `⊸`
closures by value, use-after-free detection. Errors: `‹catch›`/`‹throw›`,
compile errors with a line number, a `-g` symbol map, checked arithmetic.
Records and tooling: `⊜` records, `‹assert›`/`‹expect›` with
`tools/golftest`, the `tools/golfi` REPL, `tools/golfgdb`, and
`tools/golfdeps` packages. Two limits to watch: the list tag still owns one
band of the integers, `[0x7FFF<<48, 2^63)` (the 2^48 values just below
INT64_MAX read as lists), and any further value tag — records or dicts as
shapes of their own, say — has to come out of that band or take another; and a
program, prelude included (an empty program is about 43 KB), must fit in
192 KB, below the 1C buffer at `0x430000`. The next
candidates are still M7 (codegen) and M9 (C backend / arm64) under "As needed".

**Proposed next: W12** — [`PLAN_W12.md`](PLAN_W12.md). It comes from a
LeetCode benchmark against Python, C++ and Jelly
([`bench/leetcode/`](bench/leetcode/README.md)). It covers buffer-direct
input, faster dicts and list loops, scan and other adverbs, a constant-memory
stream protocol, store-at and vectors, and one-byte aliases. M7 is planned to
follow it.

Before W11:

**W9 — the gap-fix waves — closed the queue below.** Every numbered item
(M-TAG2, M-FRAME2, M-MEM2, M2, M6b) has shipped, along with signed `⌈ ⌊`,
literal strings, a `′undefined` diagnostic, index and divide-by-zero checks, a
guard page under the return stack, nested-list support, the missing list words
and [`REFERENCE.md`](REFERENCE.md). Each item below keeps its record of how it
was built. What is genuinely left is the "As needed" list (modules/`include`,
an object-file or C backend, a relocation pass for a peephole optimizer) and
the smaller limits DESIGN.md listed, which W10 has now closed: one-byte names
may be forward-referenced like long ones (mutual recursion between `a` and `b`
just works; a name never defined is still `GOLF: undefined word b`, now at end
of input) and a program may have 1024 long names (the prelude uses 12), up from
256 — W10-A; v1's `/` `%` report a zero divisor like `÷`/`∣` — W10-B; and the
X/Y spill stack is 4096 frames at `0x440000` instead of 28, with a checked
`GOLF: spill stack exhausted` exit — W10-C.

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
   prelude could write machine code at runtime, and `∘` did. Since W13-H a
   closure is a data record instead (`[f, g|x, kind]` on the heap, which is
   RW only): `⍎` calls anything below `0x600000` and hands anything above to
   the record's kind word (cell 2), so a new kind of closure is a new prelude
   word that fills a 3-cell block, with no compiler change.
3. **`T` is a tag test (since M-TAG2).** A list value is `addr | 0x7FFF<<48`
   (it was `addr | 2^48` until W11-1A), so "is this a list?" is
   `v >> 48 == 0x7FFF` — exact, cell-free, and cheap enough to
   ask of every element, which is what nested data needs. It used to be a range
   test against the heap window; item 1 below records why, and why the first
   scheme specified to replace it (bit 63) was wrong.
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

### 1. M-TAG2 — a real tag bit (**shipped**, W9-2A)

**Shipped as option 1 below** (DESIGN.md records it): a list value is
`addr | 2^48`, `T` is a shift and a compare, the M-VEC filter tests each
operand's high word exactly, and every list word masks on entry and tags on
exit. One correction to the plan: the two bounds cells did **not** go away —
`A` still needs the base and the span to know when to move the break — but
nothing except `A` reads them now, so the 4 GB ceiling is an allocator detail
that a prelude-only change can lift. The nested-data payoff
followed as W9-3B: `⍕` recurses, `+ - * ⌈ ⌊` vectorize to any depth, and `≣`
(structural match) and `⍤` (depth) exist. The rest of this entry is the history.

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
GOLF has been signed since M4 — `≺ ≻ ≫`, `÷`, `∣`, `N`'s sign check and (since
W9-1A) `⌈ ⌊` all say so — and any tag in the sign bit fights that.

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

### 2. M-FRAME2 — size the frame per definition — **shipped (W9-4D)**

**Shipped as sketched below** (DESIGN.md records it): `⊡` emits `sub rbp, imm32`
and every `^` an `add rbp, imm32`, their immediates threaded into a list that
`;` walks and patches with 8 × the number of distinct locals; locals take long
names (`⇒‹acc›`), slots go in order of first appearance, at most 16 a word. A
two-local word's frame is 24 bytes, not 72. The rest of this entry is the history.

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

*Also still open* (closed since: M-FRAME2 took long names, W12-Z3 all of `a`–`z`). Eight slots means eight *names*, `a`–`h`; M2's name table
(item 4, shipped) could let a `⊡` word name its locals anything and let the count fall
out of the name arena. The return stack's missing guard, which M-FRAME's
~15k-frame ceiling made easier to reach, is fixed: W9-2C's guard page turns an
overflow into a SIGSEGV instead of silent corruption (DESIGN.md, known limits).

### 3. M-MEM2 — a free list for the allocator — **SHIPPED (W9-3C)**

*What it was.* `A` bump-allocated and nothing was ever freed, so `M`, `W`, `V`,
`Z`, `K` and `G` in a loop leaked linearly.

*What shipped.* `⌫` (`\free`, 0xCA), explicit only: `list ->` releases a
tagged list or a raw `A` block. Every `A` block has a header cell `[cap]` in
front of the payload; eight free-list heads at `0x4F00C0`–`0x4F00F8` are size
classes (4, 8, … 256 cells exactly, then one list for everything larger, checked
at the head only). `A` pops the matching head before bumping and stays a
loop-free `s5` leaf. A map-and-free loop now keeps the program break flat
(run2.sh, W9-3C). Double free and freeing a non-heap value exit 1 with a message.

*Still open.* No splitting or coalescing, no walk of the large class, and no
automatic freeing — a word that consumed its input, or a scope that released
everything it allocated, would want ownership rules GOLF does not have.

### 4. M2 — multi-character identifiers (medium) — **shipped (W9-3A)**

*Shipped as* `‹name›` (`0xB4`/`0xB5`, DESIGN.md's record): long names for words,
quotations, chain links and variables, interned to name numbers 256–511 so the
dictionary and the variable bank extend by their own formulas, and **forward
references** for long names — call sites thread a per-name patch list, the
definition patches it, and a name still pending at end of input is
`GOLF: undefined word ‹name›`. Mutual recursion needs no declaration. Programs
without `‹` compile to the same bytes as before. Named locals (`⇒‹x›`)
followed with W9-4D (item 2). *Since W10-A:* forward references for one-byte
names too (same lists; the end-of-input check walks them first), and the table
is 1024 names × 60 bytes, with the dictionary and the heads moved to make room
(REGISTRY.md §3). The rest of this entry is the case that was made for it.

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
letters — and the library is missing, at minimum, index-of,
unique and a structural `≡` (concatenate and take/drop shipped in W9-4A as `⧺ ↑ ↓`; sort and member in W9-4B as `⍋ ∊`) ([`GAPS.md`](GAPS.md) §1.3). Item
5 (M6b) needed letters too, for a line reader and a number parser (it shipped
on long names once M2 landed, W9-4C). Two letters do
letters — and the library was missing, at minimum, index-of,
unique and a structural `≡`. *(All shipped now: concatenate and take/drop in W9-4A as `⧺ ↑ ↓`; sort and member in W9-4B as `⍋ ∊`; `≣` in W9-3B; and slice, index-of, unique and flatten in W9-4B part 2 as the long-named `‹slice› ‹indexof› ‹unique› ‹flatten›` — [`GAPS.md`](GAPS.md) §1.3.)* Item
5 (M6b) needs letters too, for a line reader and a number parser. Two letters do
not cover either list, so **every remaining library item is gated behind this
one** or behind spending the eight high bytes at `0xC8`–`0xCF` on words that
should have had names. That does not automatically move M2 to the front — the
tag bit is still the thing that makes the *language* correct, and it is cheaper —
but "nothing needs it" is no longer the reason to defer it. Sequencing it right
after the tag bit, and before the allocator, is the honest ordering.

### 5. M6b — a number parser and line-oriented input for USER programs — **shipped (W9-4C)**

*What it was.* A user program could read one byte with `(` and nothing more;
`lib/tio.golfj`/`lib/ttext.golfj` had buffered reads, a slurp, argv and decimal
parsing, but only `gtools/build` prepends them, and they claim `a`–`z`.

*What shipped.* Seven long-named prelude words (M2 made names free, so no
letter or high byte was spent), under the `W9-4C-INPUT` anchor:
`‹readall›` (stdin → code list), `‹readline›` (→ line without its `\n`, then a
flag: 0 got a line, 1 end of input), `‹getc›` (→ byte or -1), `‹words›`
(split a code list on ASCII whitespace), `‹num›` (signed decimal; stops at the
first non-digit, no digits → 0), `‹ints›` (all of stdin as integers) and
`‹args›` (argv[1..] as code lists). One 8 KB read buffer, made on first use and
reached through the cell `0x4F0050` (REGISTRY §3), backs all the stdin words,
so they interleave. `examples/input.golfj`; tests in run2.sh's W9-4C block,
including `printf '1 2 3' | … ‹ints›∑Ṅ` → `6`, empty input, a 1.2 MB input.

*Still open.* `(` bypasses the buffer, so a program should not mix the two.
There is no hex or float parser, no number formatter into a list, and no
output buffering for user programs (`)` is still one `write` per byte).

## As needed

- **M7 — compiler quality.** A peephole optimizer still does not fit the
  single-pass backpatch model: any *size-reducing* fold shifts every later rel32
  offset (needs a relocation pass), and a size-preserving one is perf-only. The
  real win is a register-based (top-of-stack-in-a-register) codegen, and it
  wants the relocation pass first.
- **M9 — reach.** An object-file emitter so output links with `cc`; a small IR
  to retarget (arm64) or emit C. (Textual includes shipped as `⎘`, W11-2A;
  namespaces/lexical scope and transitive package deps are still open.)
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

**W11 — Python and Rust gaps, four waves.** Each task ran in its own worktree
from the wave's base and was merged in a fixed order, with `test/gate.sh` green
after every merge and the `golf2 == golf2'` fixpoint never traded.

- **Wave 1, correctness and I/O.** 1A moved the list tag to `0x7FFF<<48`
  (`16777216 16777216* 1+Ṅ` is an integer again); 1B file words on `⎈` with
  errno-named failures; 1C buffered printers (`‹flush›`, flushed at exit and
  before every `GOLF:`); 1D text words (`‹fmt› ‹hex› ‹split› ‹trim› …`). 1E, a
  serial fix: the program image cap is 192 KB and checked by both compilers.
- **Wave 2, data and modules.** 2A `⎘“path“` (fd-0 swap, include-once, nested);
  2D a poisoned length cell catches use after free, `‹heapstats›`; 2B an
  open-addressing dict and set over `‹hash›`; 2C `⊸` bind.
- **Wave 3, errors and diagnostics.** 3A `‹catch›` over two new atoms that read
  and set rsp/rbp, unwinding the spill stack and output state too; 3B compile
  errors `at line N` (file too, inside an include) and `golfc -g`'s map; 3C
  `‹cadd› ‹csub› ‹cmul›`.
- **Wave 4, records and tooling.** 4A `⊜` records (`‹point›`, `‹point-x›`,
  `‹set-point-x›`) and `vendor/` on the include path; 4B `‹assert› ‹expect›`
  and `tools/golftest`; 4C `‹stack›` and the replaying `tools/golfi`; 4D
  `tools/golfgdb` (break, backtrace and data stack by word name); 4E
  `tools/golfdeps` and `golf.deps` (sha256-pinned git packages into `vendor/`).

Left for later, on purpose: floats, bignums, static types, a GC or borrow
checker, and threads stay refused (GAPS.md); M7 codegen, M9's C backend and
arm64, transitive package dependencies and lexical scope stay queued. The two
limits W11 leaves: integers in the list-tag band `[0x7FFF<<48, 2^63)` still
read as lists, and the image is capped at 192 KB (the prelude is about 43 KB of
it).

## Earlier waves

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
record. The third — nested lists having no support above the storage layer — was
item 1's second justification above, because the tag bit is its prerequisite;
it shipped as W9-3B (recursive `⍕`, deep `+ - * ⌈ ⌊`, `≣` match, `⍤` depth).

Two things that wave did **not** do. The `′` path still read an undefined name
as an atom (`X`'s auto-wrapping could not tell a typo from `′⊗`) — since fixed
by W9-1C, which has `X` check the blob and pass a byte that is neither to `e`'s
undefined-word diagnostic. And no diagnostic gained a source position: the compiler is
single-pass with no notion of a line, so "undefined word `b`" is the whole
message it can afford — see DESIGN.md's non-goals.

**W9-2B — runtime checks.** `⊇` (prelude `I`) bounds-checks with one unsigned
compare, and `÷`/`∣` report a zero divisor; both print `GOLF: …` to fd 2 and
exit 1 instead of returning garbage or dying of SIGFPE. `INT64_MIN ÷ -1` is
defined (wraps to `INT64_MIN`; `∣` gives 0). v1's unsigned `/` `%` were frozen
and still trapped until W10-B overrode them in the v2 blob with the same check.


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

What it deliberately did **not** do: `mkblob2.build_seed()` remained Python,
because it reused `minimal/tools/mkblob.py`'s `WORDS` — the v1 compiler's own
source text — and its `golf()` substring-rewrite pass, so a GOLF port would have
carried a second copy of source that lived in the frozen tree. Splitting the
minimal language onto its own branch removed that obstacle: the seed's source is
now `self/seed.golfv1` here, and `build_seed()` is a strip-and-splice that
`gtools/mkgolf2.golfj` already implements for the other source. Porting it is a
candidate rung, no longer a refusal. The GOLF tools still **shadow** rather than
replace, though: `tools/*.py`
is still the build path, so the repo stays buildable from Python alone and
`test/gtools.sh` is what makes the GOLF side trustworthy.
