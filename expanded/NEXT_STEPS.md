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
   suite exercises, and wrong in principle. Item 3 below is the fix — and
   the scheme this file used to specify for it was not.
4. **The compiler binary never runs the prelude**, so its M-VEC hook cells stay
   zero and it always takes the scalar path. That is the reason implicit
   vectorization did not disturb the fixpoint, and the same argument covers any
   future hook.

## The queue

The order below changed once since the roadmap closed. `M3W` (widen the
variable bank) moved to the front — it is mechanical, it fixes a wrong answer of
its own, and **every tag scheme that puts a bit above bit 31 needs it first**, or
`→x`/`←x` would truncate the tag off a list. `M-TAG2` moved back, because the
scheme it specified turns out to be wrong for a reason worth writing down (see
its entry).

### 1. M3W — widen the variable bank (small, mechanical)

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
`selfcheck.sh` was built to catch. `boot/golfref.py` mirrors both.

*Tests.* `4294967296→x←xṄ` → `4294967296`; `0 5-→x←xṄ` → `-5`; a list address
survives `→x`/`←x` and still classifies as a list; fixpoint green.

*Why first.* It is small, it is a real wrong answer, and it is the one piece of
groundwork item 3 cannot do without.

### 2. M-CHAIN2 — chain syntax, the sugar the combinators earned (medium)

*What.* `∘ ⇉ ⑂` are the threading rules of a Jelly chain, spelled as words. The
sugar is a compiler prefix that turns a `:definition;` body into links so the
rules apply *implicitly*: write `:m ∑ ≢ ÷;` and get `mean`, instead of
`:m′∑′≢′÷⑂;`. Every `′` in a tacit definition is noise the compiler can supply.

*How.* A new compiler-logic byte from the `0xB0`–`0xBF` range (REGISTRY.md §1)
introducing a *chain* definition: `⊚name link link link ;` compiles the links
into the train the explicit spelling would have built, so the compiler supplies
every `′`. It needs no driver word and no new prelude state, because the shape
of a train is decided by how many links there are:

| links | the chain is | what it compiles to |
|-------|--------------|---------------------|
| 0 | identity | nothing |
| 1 | `f x` | a plain call to `f` |
| 2 | `g(f x)` — atop | two plain calls |
| 3 | `h(f x, g x)` — a fork | `′f ′g ′h ⑂`, exactly today's spelling |
| n>3 | the fork, then the rest in sequence | `′f ′g ′h ⑂` then plain calls |

So the compiler only has to buffer the first three link bytes: on the third it
emits the three `′` pushes and the `⑂` call, after that a link is an ordinary
call, and `;` flushes a 1- or 2-link chain as plain calls. That is one new case
in `t`, one flag and four cells of compiler state, and a `;` that checks the
flag. The `′` case's body becomes a word (`X`) so the chain and `′` share the
one copy of "push the address of the word or atom named by this byte". Written
in `self/golf2.golfj` **and** mirrored into `mkblob2.py`'s v1-GOLF seed and
`boot/golfref.py`, or `selfcheck.sh` catches the drift.

*Limits, stated up front.* A link is a single token naming a word or an atom —
the same thing `′` accepts. Digits, `“…“`, `[`, `{`, `→x` and `′` inside a chain
body keep their ordinary meanings rather than becoming links, and a chain of
three or more links compiles a call to `⑂`, so it needs the prelude.

*Tests.* `⊚m∑≢÷;5⍳mṄ` → `2`; it emits byte-for-byte what `:m′∑′≢′÷⑂;` emits; the
explicit form keeps working; 1-, 2- and 4-link chains; fixpoint green.

*Why here.* It is the one remaining piece of the Jelly surface, it is the payoff
for M-SELF (new compiler logic written in the pleasant language), and it is pure
notation — no representation change to collide with anything below.

### 3. M-TAG2 — a real tag bit (medium — **the specified scheme is wrong**)

*What.* Retire the range test. `T` is `v - base <u span` today, so an *integer*
that happens to land in `[base, base+span)` is dispatched as a list — the one
outright incorrect behavior in the language (DESIGN.md, known limits). Range
tagging also forces the two 32-bit bounds cells at `0x4F0034`/`0x4F0038`, which
put a hard 4 GB ceiling on the break.

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

Option 1 is what a future wave should implement, and it must land **after**
item 1 (M3W): a `2^48` tag does not survive a 4-byte variable cell.

*Fixpoint impact.* Same argument as M-VEC: the compiler never runs the prelude,
its hooks stay zero, and both golf2 and golf2' embed the new blob. Real but
contained, and the ladder verifies exactly this.

*Tests.* The regression that cannot pass today — take the heap base out of the
bounds cell, hand it to `+` as an *integer*, and require scalar addition — plus
the one that guards the fix: `0 1-T` is still an int, and so is every negative a
program can produce. Every existing polymorphic test unchanged;
`0x4F0034`/`0x4F0038` deleted from REGISTRY.md §3 in the same commit.

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
tag bit (item 3) first so a header cell can never be mistaken for a value.

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

*Coordinate first.* M-TOOL (the wave porting the build scripts to GOLF) is
taking `0xA7` for a general `\sys` syscall atom and is building its own I/O
words. Whoever gets there second should use that atom rather than allocate a
second one — check REGISTRY.md §1 before writing any code here.

## As needed

- **M7 — compiler quality.** A peephole optimizer still does not fit the
  single-pass backpatch model: any *size-reducing* fold shifts every later rel32
  offset (needs a relocation pass), and a size-preserving one is perf-only. The
  real win is a register-based (top-of-stack-in-a-register) codegen, and it
  wants the relocation pass first.
- **M9 — reach.** `include`/modules; an object-file emitter so output links with
  `cc`; a small IR to retarget (arm64) or emit C.
- **Shape checks.** `Z` truncates to the shorter list and nothing reports a rank
  mismatch. With a real tag (item 3) `D` can afford to say so.

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

## The wave in flight

**M3W then M-CHAIN2** — items 1 and 2. Both live entirely in the compiler's
front end (`self/golf2.golfj`, `mkblob2.py`'s v1-GOLF seed cases,
`boot/golfref.py`) and neither touches a representation, so they compose: the
bank widening lands first because it is the smaller change and the one every
later tag scheme depends on, and the chain sugar lands on top of it.

Item 3 (the tag bit) is **not** in this wave. It was the better engineering
right up until the specified scheme turned out to misclassify every negative
integer; it goes back on the queue with a corrected design rather than shipping
a regression. Item 5 and the shape checks stay behind it, as they always were.

**Parallel work.** M-TOOL — the repo's build scripts rewritten in expanded GOLF
— is in flight on its own branch. It owns `0xA7 \sys`, the entry-`rsp` cell at
`0x4F0040`, the lowercase library letters and everything under `gtools/`; this
wave owns the compiler's front end and touches none of them. The one shared file
is `tools/mkblob2.py`, where the two waves edit different halves (its `ATOMS`
table versus its spliced compiler cases).
