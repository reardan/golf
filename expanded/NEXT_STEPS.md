# Expanded GOLF — next steps

The prioritized queue for the expanded language. [`DESIGN.md`](DESIGN.md) holds
the vision, the bootstrap ladder, the record of what shipped and the known
limits; this file is the forward plan: what to build next, in what order, and
why. Every step keeps the two invariants: `test/run2.sh` stays green **including
the golf2 self-hosting fixpoint**, and `../minimal/` is never touched.

## Where we are

The original roadmap is done. The code page, the atom set, lists on a `brk`-grown
heap, quotations and higher-order words, strings, named variables, a total list
runtime, shape polymorphism, *implicit* vectorization on the bare `+ - * ⌈ ⌊`,
tacit combinators built at runtime, 64-bit values with big literals, and the
compiler's own source migrated to v2 GOLF — all shipped, with `run2.sh` and
`selfcheck.sh` green. (The current counts and sizes live in DESIGN.md's table,
where the suite asserts them.)

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
   suite exercises, and wrong in principle. Item 2 below is the fix.
4. **The compiler binary never runs the prelude**, so its M-VEC hook cells stay
   zero and it always takes the scalar path. That is the reason implicit
   vectorization did not disturb the fixpoint, and the same argument covers any
   future hook.

## The queue

### 1. M-CHAIN2 — chain syntax, the sugar the combinators earned (medium)

*What.* `∘ ⇉ ⑂` are the threading rules of a Jelly chain, spelled as words. The
sugar is a compiler prefix that turns a `:definition;` body into links so the
rules apply *implicitly*: write `:m ∑ ≢ ÷;` and get `mean`, instead of
`:m′∑′≢′÷⑂;`. Every `′` in a tacit definition is noise the compiler can supply.

*How.* A new compiler-logic byte from the `0xB0`–`0xBF` range (REGISTRY.md §1)
introducing a *chain* definition: the compiler collects the links of the body as
word addresses rather than compiling calls, then emits one call to a prelude
driver that applies the fixed monadic/dyadic threading rule to the collected
list. The links are already ordinary quotations, so the driver is `⇉`/`⑂` logic
in `lib/prelude.golfj` — the compiler-side change is a token that pushes
addresses instead of calling them, which `′` already proves is a five-line case.
Written in `self/golf2.golfj` **and** mirrored into `mkblob2.py`'s v1-GOLF seed,
or `selfcheck.sh` catches the drift.

*Tests.* `:m∑≢÷;5⍳mṄ` → `2`; the explicit `′∑′≢′÷⑂` form keeps working (it is
what the sugar expands to); fixpoint green.

*Why first.* It is the one remaining piece of the Jelly surface, it is the
payoff for M-SELF (new compiler logic written in the pleasant language), and it
is pure notation — no representation change to collide with items 2 and 3.

### 2. M-TAG2 — a real tag bit (medium, fixes a known wrong answer)

*What.* Retire the range test. `T` is `v - base <u span` today, so an *integer*
that happens to land in `[base, base+span)` is dispatched as a list — the one
outright incorrect behavior in the language (DESIGN.md, known limits). Range
tagging also forces the two 32-bit bounds cells at `0x4F0034`/`0x4F0038`, which
put a hard 4 GB ceiling on the break.

*How.* Tag the *list*, not the int: a heap address is handed to user code with
bit 63 set, and every prelude word masks it off before dereferencing. Then `T`
is a shift — exact, constant, no cells — and the M-VEC preamble's conservative
`(a|b) <u heap-base` filter becomes an exact `(a|b) >> 63`, so the templates get
*shorter* as well as correct. `A` sets the bit on the address it returns; `I`,
`L`, `M`, `F`, `W`, `V`, `Q`, `J`, `U`, `Z`, `K`, `G`, `D` clear it on entry.
Nothing outside `lib/prelude.golfj` dereferences a list, so the blast radius is
one file plus five templates.

*Why not the classic scheme.* Tagging the *int* (bit 0, Lisp-style) would make
every arithmetic template shift and unshift — GOLF's atoms are raw one-instruction
templates and that is the whole aesthetic. Tagging the pointer costs one `btr`
per dereference in library code that is already doing a memory access.

*Fixpoint impact.* Same argument as M-VEC: the compiler never runs the prelude,
its hooks stay zero, and both golf2 and golf2' embed the new blob. Real but
contained, and the ladder verifies exactly this.

*Tests.* The regression that cannot pass today — take the heap base out of the
bounds cell, hand it to `+` as an *integer*, and require scalar addition; every
existing polymorphic test unchanged; `0x4F0034`/`0x4F0038` deleted from
REGISTRY.md §3 in the same commit.

### 3. M3W — widen the variable bank (small, mechanical)

*What.* `→x`/`←x` go through a 4-byte-per-name bank at `0x4E0000` and `←x` is a
`mov eax`, so `4294967296→x←x` is `0` and `0 5-→x←x` is `4294967291`. Every
other place a value can sit — the data stack, the atoms, list cells, the prelude
scratch bank — has been 64 bits since M4. This is the last narrow one.

*How.* Exactly the job W4A did for scratch: stride 4 → 8. `SET_CASE`/`GET_CASE`
in `tools/mkblob2.py` become `mov [0x4E0000+8*name], rax` / `mov rax,
[0x4E0000+8*name]`; 256 names × 8 bytes = 2 KB, still inside the
`0x4E0000`–`0x4F0000` hole, so no address needs reallocating. Because these are
compiler-emitted templates they exist in *both* `self/golf2.golfj` and the
seed's spliced cases and must change in lockstep — which is precisely the drift
`selfcheck.sh` was built to catch.

*Tests.* `4294967296→x←xṄ` → `4294967296`; `0 5-→x←xṄ` → `-5`; a list address
survives `→x`/`←x` and still classifies as a list; fixpoint green.

### 4. M-FRAME — per-call locals (medium)

*What.* The variable bank is **global**: a recursive word does not get fresh
copies, so `→x` inside recursion is a footgun. This is the one M3 shortcut that
users will actually trip over once programs have recursive words with state.

*How.* The return stack is already a private, rbp-relative stack that `X`/`Y`
push frames on. Give a definition a prologue that reserves *n* cells below `rbp`
and a matching epilogue, and add a second pair of prefixes (two bytes from
`0xB0`–`0xBF`) that resolve a name to a frame slot rather than a bank index. The
cheap version needs no symbol table: a fixed 26-slot frame indexed by the letter,
allocated per definition. The good version wants M2's name arena (item 6), which
is why this sits behind the sugar and the tag but ahead of the allocator.

*Tests.* A recursive word that stores to a local and still returns the right
answer at depth; globals via `→x`/`←x` unchanged; fixpoint green.

### 5. M-MEM2 — a free list for the allocator (small-medium)

*What.* `A` bump-allocates and nothing is ever freed. Since `M`, `W`, `V`, `Z`,
`K` and `G` each allocate a fresh list per call, a map inside a loop leaks
linearly — the heap grows with `brk` now, so it does not crash, it just climbs.

*How.* Keep the bump pointer as the fast path and give each block a header cell
carrying its size (the length header nearly is one already). Add a `free` word
that threads a released block onto a size-classed free list; `A` checks the
matching class before bumping. A first cut can be one list and exact-fit only —
the allocation pattern here is overwhelmingly "same-size list, over and over".

*Why here.* It is invisible until a program is long-running, and it wants the
tag bit (item 2) first so a header cell can never be mistaken for a value.

### 6. M2 — multi-character identifiers (medium)

*What.* Word names are single bytes and the uppercase prelude pool is down to
`B` and `C` (REGISTRY.md §2). The code page removed the pressure on *operators*,
not on *names*: a user program with a dozen helpers is out of readable letters.

*How.* As always planned: a real tokenizer, a name arena, and two-pass or
forward-declaration handling so mutual recursion needs no pending-char hack.
The high-byte word range `0xC0`–`0xCF` is the stopgap the prelude already uses;
M2 is what makes it unnecessary.

*Why not sooner.* Nothing above needs it, and it is the largest single change to
the compiler's front end — best done when the language has stopped moving under
it.

### 7. M6b — input, and a number parser (small)

*What.* GOLF can print but not read: there is no `read` atom and no way to turn
digits into a number. That is the difference between "a compiler demo" and "a
language you can point at a puzzle input".

*How.* One atom (`0x97` or `0xA7`, both spare — REGISTRY.md §1) for the read
syscall, then pure prelude: a line reader over a fixed buffer, a decimal parser,
and a split-on-whitespace that yields a list. `U` already turns bytes into a
list of codes, so the parser is a fold over that.

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
  mismatch. With a real tag (item 2) `D` can afford to say so.

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

## Suggested first move

Item 1 (chain syntax) and item 2 (the tag bit) are independent — one is
notation, one is representation — and together they close the last gap in the
Jelly surface and the last wrong answer in the language. Item 1 is the better
demo; item 2 is the better engineering. Doing 2 first makes 5 and the shape
checks cheap, and shortens five templates on the way through.
