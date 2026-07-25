# Expanded GOLF — next steps

The prioritized queue for the expanded language. `DESIGN.md` holds the vision,
the bootstrap ladder, and the record of shipped milestones; this file is the
forward plan: what to build next, in what order, and why. Every step keeps the
two invariants: `test/run2.sh` stays green **including the golf2 self-hosting
fixpoint**, and `../minimal/` is never touched.

## Where we are

51/51 tests green. Shipped: the code page, the atom set, lists + prelude,
quotations/HOFs (`′`/`⍎`, map/fold/filter/zip), strings, named variables, and
explicit vectorization (`⊞` zip + closure broadcast). The 1156-byte seed still
bootstraps from the frozen v1 compiler and self-hosts to a byte-identical
fixpoint.

Three facts about the implementation shape everything below:

1. **Templates dispatch before words.** The compiler tries the template blob
   before the word dictionary, so an atom byte can never be shadowed by a
   prelude definition. Making a *bare* `+` vectorize therefore has to happen
   inside the `+` template itself — it cannot be done from the library.
2. **The whole load segment is RWX** and a quotation is just an address. `′+`
   already emits a compile-time thunk; nothing stops the *prelude* from writing
   thunks into the heap at **runtime**. That makes compose/closures a library
   feature, no compiler change.
3. **`{…}` is a do-while** — the body always runs at least once. Every prelude
   loop inherits this, which is exactly the known empty-list gap.

## The queue

### 1. M-SOUND — make the list runtime total (small)

*What.* Fix the two known correctness gaps: every prelude loop misbehaves on an
empty list (`S` sums garbage, `M`/`W`/`V`/`Q`/`J`/`U`/`Z` iterate once on
nothing), and `Z` trusts `l1`'s length, reading past the end of a shorter `l2`.

*How.* Guard each loop with the existing atoms — `≢ 0 ≡ [ {…} ]` runs the loop
only when the length is nonzero (`[` executes on TOS==0) — and have `Z` take
`⌊` min of the two lengths. Pure `lib/prelude.golfj` change; the compiler and
fixpoint are untouched.

*Tests.* `0⍳∑Ṅ` → `0`; `0⍳≢Ṅ` → `0`; map/filter/reverse/print over `0⍳`;
`“““U≢Ṅ` → `0`; zip of a 3-list with a 5-list → length 3.

*Why first.* Everything after this builds on the list runtime; it should be
total before we make atoms dispatch into it.

### 2. M-TAG — a shape predicate + polymorphic library words (medium)

*What.* The cheapest runtime answer to "is this an int or a list": lists are
heap addresses and the heap starts at `0x500000`, so `value ≥ 0x500000` *is* a
type tag. Add an `isl` prelude word for it, then polymorphic arithmetic words
(`vadd`, `vsub`, `vmul`, `vmin`, `vmax` — glyphs picked at implementation
time) that dispatch on the shapes of their two operands:

| shapes        | behavior                                  |
|---------------|-------------------------------------------|
| int, int      | the plain atom                             |
| list, list    | `Z` zip with the atom                      |
| int, list / list, int | broadcast: `M` map a closure       |

*Honest caveat.* Range tagging means an integer ≥ `0x500000` (~5.2M) is
misread as a list. Document it; the real fix is a tag bit, which lands
naturally in M4 when the value representation is revisited anyway.

*Fixpoint impact.* None — library only. This is the low-risk half of implicit
vectorization, and it front-loads the dispatch logic that M-VEC's templates
will call into.

*Tests.* `4⍳4⍳vmul∑Ṅ` → 14 (dot product, no `′`/`⊞` spelled out);
`3 5⍳vadd∑Ṅ` → 25 (broadcast); scalar/scalar still exact.

### 3. M-VEC — bare atoms vectorize (finishing M-JELLY's frontier)

*What.* `4⍳3+` should broadcast and `4⍳4⍳*` should zip — with the ordinary
atom bytes, like Jelly. Since templates outrank words (fact 1), the dispatch
goes in the template: the polymorphic version of `+` checks both operands
against `0x500000`; the scalar path is inline as today; the list path does an
absolute indirect call through a **hook cell** (e.g. `call [0x4F0100 + 4*byte]`,
position-independent, legal in a copied template). The prelude stores the
address of its M-TAG dispatch word into the hook at startup; hook == 0 means
"no prelude" and the template falls back to the scalar path.

*The sharp edge.* The prelude itself does pointer arithmetic on heap addresses
(`I` is `4*+4+@`) — under a polymorphic `+` that would recurse into the
dispatcher. So the scalar templates don't disappear: they move to fresh bytes
(`0x91+` is free, ~110 slots), spelled e.g. `\radd`, and the prelude's internal
pointer math migrates to them. User-visible bytes become polymorphic; raw ops
stay available for systems code.

*Fixpoint impact.* Real but contained: the compiler binary contains the new
templates and runs them on its own values, but every value the compiler
computes is < `0x500000` (code VAs top out near `0x410000`) and its hook cells
are 0, so it always takes the scalar path. The three-stage ladder verifies
exactly this.

*Tests.* `4⍳3+QE` → `3 4 5 6`; `4⍳4⍳*∑Ṅ` → 14; all existing scalar tests
unchanged; fixpoint green.

### 4. M-CHAIN — tacit building blocks: compose, pipeline, fork (medium)

*What.* The first slice of Jelly-style chains, as pure library, using fact 2
(RWX heap → runtime code generation):

- **`compose`** (`f g → fg`): allocate a small heap block, write
  `[prologue] mov rax,f; call rax; mov rax,g; call rax [epilogue]` with the
  byte-store op, return its address. `mov rax,imm64; call rax` needs no
  relocation math, so the thunk is straight stores. Now quotations compose
  into new quotations.
- **`pipeline`** (`x list-of-quotations → y`): thread a value left to right —
  this is just `F` fold with `⍎`.
- **`fork`** (`x ′f ′g ′h → h(f(x), g(x))`), the classic tacit combinator:
  `mean` becomes `′∑ ′≢ ′÷ fork`, and `5⍳ ′∑′≢′÷ fork Ṅ` prints `2`.

*Why this slice.* Chains in Jelly are "a sequence of links threaded by fixed
monadic/dyadic rules." Compose + fork + pipeline are those rules as explicit
words; once they exist and get exercised, a chain-*syntax* (a compiler prefix
that packs a `:definition;` into links) is a small follow-up rather than a
leap.

*Fixpoint impact.* None — library only.

### 5. M4 — 64-bit values (medium, mechanical)

Less work than it looks: the stack and arithmetic templates are already
64-bit. What is actually 32-bit today, and the change for each:

- **Literals** — `push imm32`, capped at 2³¹. Add a big-literal path in the
  compiler (`mov rax, imm64; push rax` when the value doesn't fit).
- **`@` / `!`** — fetch/store are 32-bit. Widen them (or add 64-bit variants
  at new bytes first, migrate, then swap).
- **List cells** — 4 bytes throughout the prelude (`4*`, `4+`). Mechanical
  widen to 8.
- **Signed compare + `shl`** — the missing signed atoms; `»`/`<` stay
  unsigned for addresses.
- **`Ṅ`** — grows a sign check (print `-`, negate via `±`).

This is also the moment to revisit tagging (M-TAG's caveat): with 64-bit
cells there is room for a real tag bit without sacrificing usable range.

*Order note.* Scheduled after M-CHAIN because everything above is
representation-agnostic, and doing M4 first would just widen code that the
earlier steps are about to touch anyway.

### 6. M-SELF — golf2 written in expanded GOLF (the ladder's promised rung)

*What.* DESIGN.md promised: "as soon as golf2 gains a feature that makes it
easier to write, we migrate golf2's own source." Named variables are that
feature — most of the seed's `\`-juggling melts into `→x`/`←x`. The ladder
grows a rung:

```
golf0.py → v1c → seed (v1 GOLF, frozen-ish) → golf2 (source in v2 GOLF) → fixpoint
```

The seed stays generated by `mkblob2.py` and only needs the features the v2
source uses; the maintained compiler source becomes the pleasant one. From
then on, new compiler logic (M4's big-literal path, a chain prefix) is written
in expanded GOLF — the payoff the whole bootstrap strategy was built for.

*Tests.* `run2.sh` gains the extra stage; the fixpoint moves to the new last
rung and must still be byte-identical.

### 7. M-MEM — a real allocator + heap safety (small-medium)

The bump heap at `0x500000` sits below the return stack (which grows down from
`0xC00000` inside the same 8 MB segment) — big allocations can silently
collide with it, and nothing grows. Steps, in value order: (a) move the heap
above the return-stack region and size it with `brk` so it can grow; (b) keep
the bump allocator but make `A` check/extend via `brk`; (c) a free-list only
if programs ever actually need it. Closes the M5 leftover ("a real data
section / allocator").

## As needed (unchanged from DESIGN.md)

- **M2 multi-char identifiers** — when programs outgrow single-byte names.
- **Frame-based locals** — when recursion + variables actually collide.
- **M7 compiler quality** (register-based codegen, relocation pass) and
  **M9 reach** (modules, object emitter, retargeting) — deferred as before.

## Hygiene along the way

- Every new atom lands in `tools/mkblob2.py` *and* `boot/golfref.py` (oracle
  parity), with a `codepage.py` row and a `run2.sh` case — same discipline as
  today.
- Keep printing the seed size in `run2.sh` (1156 bytes now); creeping growth
  is a smell in a golf language.
- Each milestone ships with a one-line example in `examples/` — the capstone
  program should keep getting shorter as vectorization and chains land.

## Suggested first move

M-SOUND and M-TAG together make a natural next PR: one prelude-only change
that makes the list runtime total and gives the language its first
shape-polymorphic operators, zero fixpoint risk, and it stages the dispatcher
that M-VEC's templates will call.
