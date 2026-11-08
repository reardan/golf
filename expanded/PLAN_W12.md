# W12 plan — speed, size, adverbs and streams

**Goal.** Make Golf competitive on LeetCode-style problems. "Competitive"
means three measurable things:

- Golf beats Python on all 10 benchmark problems. Today it wins 6.
- The Golf solutions total about 600 bytes. Today they total 898.
- A stream pipeline (stdin → scan → fold) runs in constant memory.

Do all of this without trading the `golf2 == golf2'` fixpoint or touching the
frozen v1 substrate.

The evidence is the benchmark in [`bench/leetcode/`](bench/leetcode/README.md):
10 LeetCode problems solved in Golf, Python, C++ and Jelly, all outputs
cross-checked. The write-up is the doc *Golf vs Python, C++ and Jelly on
LeetCode* (https://claude.ai/artifact/BbLz4w9y9FR4jZR5mu6C9M). This file is
the plan that follows from it. It is a plan only. Nothing here is built yet.

## 1. What the benchmark found

| | Golf | Python | C++ | Jelly |
|---|---|---|---|---|
| Bytes, 10 problems | 898 | 2,571 (golfed: 1,300) | 4,613 | 144 |
| Faster than Python on | 6 of 10 | — | 10 of 10 | 0 of 10 |
| Peak memory, 1M-int input | 179 MB | 77 MB | 13 MB | — |

1. **Input is the bottleneck.** `‹ints›` is `‹readall›‹words›′‹num›€`. It
   builds a code list (8 bytes per input byte), then a list of lists, then
   the ints. That takes 0.19–0.54 s, which is 64–93% of Golf's time on the 7
   problems that use it. A 2-line `‹getc›` parser written in Golf
   (`bench/leetcode/golf/stream_ints_proto.golfj`) does 1M ints in 0.07 s and
   13 MB, against 0.52 s and 179 MB for `‹ints›`.
2. **The core is between C++ and Python, but list words have a high fixed
   cost per element.** Microbenchmarks, 10M elements unless noted:

   | Measurement | Golf | C `-O2` |
   |---|---|---|
   | Bare `{⊖"0≡}` loop | 0.9 ns/iteration | — |
   | `⍳` | 9 ns/element | about 2 |
   | `∑` | 15 ns/element | about 0.5 |
   | `€` with an empty word | 17 ns/element | — |
   | Vectorized `l"+` | 34 ns/element | about 1 |
   | `‹put›` (int keys, 1M) | 560 ns/insert | Python: about 100 |

   Each looping prelude word keeps its index, list and accumulator in the
   scratch cells at `0x4F0060..` and fetches and stores them every
   iteration. It also saves and restores all 8 of them (`X`/`Y`) around
   every call.
3. **Dicts are about 5x slower than Python's.** A counter bump is
   `‹has›`, then `‹get›`, then `‹put›`: three hashes and three structural
   compares. That is why Top K loses even before input is counted.
4. **Most bytes are bookkeeping.** In the long solutions, 25–50% of the bytes
   are `←x`/`→x` traffic and long names. Index counters, hand-rolled stacks
   (`←b←p8*﹢⊛`), early-return else (`[…0^]`) and packed sort keys make up
   the rest. Golf has no way to store into a list, push, pop, sort by key,
   get the index in a map, or write an else.
5. **`€` already threads state.** Its function runs with the element on top
   of the caller's stack, so `:s+";0 l′s€` is a running sum. Stock, Product
   and Trap rely on this and are Golf's three shortest solutions (26–33
   bytes, within 3–8x of Jelly). It is not documented, so nothing promises
   it.
6. **Footguns.**
   - Scalar atoms (`⊕ ⊖ ² ⊗ ⊘ ±`) silently do pointer math on a list.
   - One-letter locals stop at `h`.
   - Every `∘`/`⊸` thunk comes from a code arena that is never freed. A
     program gets about 1,700 in its life, so combinators built inside a
     loop run out.

## 2. Targets

The gate for the round is the benchmark at the end of the last wave:

| Problem | Bytes now → target | Golf s now → target (large input) | Python s |
|---|---|---|---|
| twosum | 92 → 65 | 0.293 → 0.10 | 0.096 |
| parens | 131 → 90 | 0.147 → 0.07 | 0.155 |
| stock | 26 → 15 | 0.566 → 0.06 | 0.235 |
| longsub | 62 → 45 | 0.142 → 0.07 | 0.349 |
| prodself | 32 → 22 | 0.411 → 0.12 | 1.175 |
| topk | 127 → 60 | 0.564 → 0.08 | 0.087 |
| islands | 158 → 110 | 0.089 → 0.06 | 0.559 |
| trap | 33 → 21 | 0.620 → 0.10 | 0.292 |
| slidemax | 127 → 25 | 0.633 → 0.12 | 1.406 |
| queens | 110 → 85 | 0.022 → 0.02 | 0.169 |
| **total** | **898 → about 540** | **beat Python on 10 of 10** | |

There are two more targets:

- Peak memory for `stock` ≤ 30 MB with `‹ints›`, and ≤ 1 MB of heap with the
  stream version.
- No regression on `test/gate.sh`.

The byte targets come from rewriting each solution by hand with the proposed
words. The speed targets assume P1–P3 and leave M7 as headroom.

## 3. The work

Four tracks. Item ids are what the waves (section 4) schedule.

### P — performance

- **P1. Buffer-direct input.** Rewrite `‹ints›`, `‹words›` and `‹num›` to
  scan the 8 KB stdin buffer directly and append to one result list. They
  should never build the intermediate code list. Add `‹readbytes›`
  (`-> block`), which returns the rest of stdin as a `“…“`-style byte block:
  1 byte per byte, not 8. `⊃` still turns it into a code list when a list is
  wanted. `‹readall›` keeps its meaning.
  *Acceptance:*
  - `‹ints›` on `bench/leetcode/in/stock.txt` runs in ≤ 0.08 s and peaks at
    ≤ 30 MB.
  - `‹ints›` gives the same results on every input in `test/run2.sh`'s W9-4C
    cases.
- **P2. Dicts that hash once.**
  - Add `d k f ‹upd›` (update in place by `f`, inserting `0` first when the
    key is missing).
  - Add `d k dflt ‹getor›`.
  - Add `d k ‹bump›` (increment, inserting at 1).
  - Add an int-key fast path in the probe: when both the key and the slot are
    untagged ints, compare with `≡` and skip `≣`.
  - Inline the FNV loop for a single int.

  *Acceptance:*
  - 1M int `‹put›` in ≤ 0.15 s.
  - 1M `‹bump›` in ≤ 0.15 s.
  - Existing W11-2B cases unchanged.
- **P3. Tight list-word loops.**
  - Rewrite the hot loops (`⍳ ∑ ∏ € ⇤ ⌿ ⊞ ⌽` and the M-VEC elementwise path)
    to keep the index and the end pointer on the data stack, walking an
    element pointer. They should not fetch and store scratch cells per
    element.
  - Call `X`/`Y` once per word, not per element. They are only needed around
    the user's function, and only if that function can re-enter the word.
    Measure the current behaviour first.
  - Give the elementwise path a flat-int-list fast loop. Recurse only when an
    element is itself a list.

  *Acceptance:*
  - `⍳` ≤ 4 ns/element, `∑` ≤ 3, `€` ≤ 8, vectorized `+` ≤ 6.
  - Every list-word case in `run2.sh` unchanged.
  - Spill-stack and catch-unwinding cases unchanged.
- **P4. A perf harness in the tree.**
  - Add `bench/micro/`: the microbenchmarks above as `.golfj` files, plus a
    script that prints ns/element.
  - Add `bench/leetcode/bench.sh` and `bytes.sh`, already present.
  - Neither gates. Timing is noisy on shared machines.
  - Record each wave's numbers in `bench/RESULTS.md`, one dated row per
    wave.
- **P5. M7, register codegen (separate, after this round).** Keep the queued
  M7 sequence:
  1. A relocation pass, so size-changing folds are possible.
  2. Top-of-stack in a register.

  Expected 2–3x on scalar loops (`queens`, `islands`). It is listed here so
  the round's numbers are not mistaken for the ceiling. It needs its own
  plan, because it touches the fixpoint.

### Z — code size

- **Z1. One-byte aliases for the hottest long names.**
  - Count long-name uses across `examples/`, `bench/leetcode/golf/`,
    `gtools/` and `lib/`. Give the top ones a high byte as prelude words.
    Candidates: `‹ints›`, `‹readall›`, `‹dict›`, `‹get›`, `‹put›`, `‹has›`,
    `‹keys›`.
  - Each saves 5–9 bytes per use.
  - The long name stays, as a one-call alias.
  - Budget: at most 7 bytes from `0xD1`–`0xD7`, plus whatever of
    `0xD8`–`0xEF` W12-0 releases (that range is "reserved: chain syntax";
    chain syntax shipped at `0xB0`, so the reservation is stale).
- **Z2. Variable increment and decrement prefixes.**
  - `⇡x` and `⇣x` (compiler ops, `0xB9`/`0xBA`) for `←x⊕→x` and `←x⊖→x`.
  - 5 bytes become 2 at every counter. Every loop in the benchmark has one.
  - Also `⇑x` and `⇓x` for locals, if the byte budget allows. Otherwise,
    locals only via `⇐x⊕⇒x`.
- **Z3. Locals `a`–`z`.**
  - The frame already has 16 slots. Allow any lowercase letter as a
    one-byte local, sized per definition as M-FRAME2 already does.
  - `local out of range` remains only for a 17th distinct local.
- **Z4. Store-at and a growable vector** (data structures; size and speed).
  - `l i v ⍈` stores into a list (bounds-checked, `use after free`-checked).
    It is the missing twin of `⊇`.
  - `‹vec›`, `⍆` push and `⍅` pop (`v x -> v`, `v -> v x`): a tagged list
    whose capacity doubles. The length cell stays the first cell, so every
    list word still reads it.
  - `‹deque›` with `‹pushf› ‹popf›`.
  - Valid Parentheses, Islands and Sliding Window lose their raw-memory
    stacks.

### A — scan, adverbs and the stream protocol

- **A1. Make the stack-threaded `€` a contract.**
  - Document in REFERENCE.md and DESIGN.md that `€ ⇤ ⌿ ⊞` call their
    function with the caller's stack underneath. The function may read and
    leave values there, and the list words never touch the user's stack.
  - Add run2 cases: a running sum, a running max, map-with-accumulator.
  - P3 must keep this true. Its acceptance includes these cases.
- **A2. Scan `⍀` and reduce `⍁`.**
  - `l ′f ⍀ -> l'` is an inclusive scan: the first element is the seed and
    the result has the same length.
  - `l ′f ⍁ -> x` folds with no seed: the first element is the seed, and an
    empty list throws `empty reduce`.
  - Scan from the right is `⌽…⍀⌽`. Its own byte waits for data.
- **A3. Each-with-index `⍸`.** `l ′f ⍸ -> l'`: `f` is called with `x i`.
- **A4. Sort by key and grade.**
  - `l ′k ⍒ -> l'`: a stable sort by `k x`, ascending. Descending is
    `′(k ±)`.
  - `l ‹grade› -> perm`: the permutation that sorts `l`.
  - Both reuse `⍋`'s merge sort, on (key, index) pairs.
- **A5. Window reduce `⊟`.**
  - `l n ′f ⊟ -> l'` gives `f`-reduce of every length-`n` window.
  - When `f` is the address of `⌈` or `⌊` (or their wrappers), it runs a
    monotonic deque: O(n) rather than O(n·k).
- **A6. Fixpoint `⍣`.**
  - `x ′f ⍣` applies `f` until the result `≣` the previous one: Jelly's
    `ÐL`.
  - Jelly's Valid Parentheses and Islands are built on it, and both are
    O(n²) in the worst case. Document that.
- **A7. If-else and a top-tested while, as compiler syntax.**
  - `c[a⋄b]` runs `a` when `c` is `0` and `b` otherwise.
  - `{?c⋄body}` tests `c` before each pass.
  - `⋄` is one new compiler op (`0xB8`, W11's unused spare). Both forms
    compile to the same jumps `[ ] { }` emit today, so they cost nothing at
    run time.
  - Lives in `self/golf2.golfj`, the v1-GOLF seed and `boot/golfref.py`, with
    selfcheck parity.
  - The quotation forms (`′c′b‹while›`) are deliberately *not* added. An
    indirect call per pass is the wrong cost for a loop.
- **A8. Streams, the constant-memory protocol.**
  - **Shape.**
    - A stream is a tagged list `[step, state…]`.
    - `s ⍞ -> s x 0 | s 1` calls `step` with the record. `⍞` is `‹next›` at a
      byte.
    - The flag is zero-is-true, like `‹readline›`.
    - Streams live on the heap, so `⌫` frees one.
    - They need no thunks and nothing from the compiler: `∘`'s
      never-freed arena is exactly what this shape avoids.
  - **Sources:**
    - `‹sints›`: P1's parser, incremental, one int per `⍞`.
    - `‹slines›`, `‹sbytes›`.
    - `n‹upto›` (lazy `⍳`), `‹nat›` (endless).
    - `l‹stream›` (list to stream).
  - **Transformers:** `‹smap› ‹sfilter› ‹sscan› ‹stake› ‹sdrop› ‹swhile›
    ‹senum› ‹szip› ‹swin›`. The function is applied as `€` applies it, with
    the stack-threading contract of A1.
  - **Sinks:** `‹sfold› ‹collect› ‹sshow› ‹sfind›`. `‹sfind›` stops at the
    first hit and reads no further input.
  - **Acceptance:**
    - `‹sints›′⌊‹sscan›…‹sfold›` (Stock as a stream) over 100M ints keeps
      `‹heapstats›` bytes flat, within 64 KB.
    - It reads 1M ints in ≤ 0.1 s.
    - `‹stake›` on `‹nat›` terminates.
    - Every word has a run2 case and a REFERENCE.md row.
  - Glyphs for more than `⍞` wait until usage data shows which stream words
    are hot (Z1's method).

### O — other improvements

- **O1. Atoms on lists.** `⊕ ⊖ ² ⊗ ⊘ ± ≪ ≫ > $ | = ~` on a tagged list
  currently compute on its address.
  - Recommendation: throw `GOLF: not a number` from the M-VEC hook, so the
    atom stays one instruction on ints.
  - The alternative is to vectorize them like `+`.
  - The choice is the user's. See open questions.
- **O2. Freeable thunks.**
  - Allocate `∘` and `⊸` thunks from the heap (an executable size class) so
    `⌫` can release them.
  - Remove the 1,700-thunk lifetime cap.
- **O3. Priority queue.**
  - `‹pq› ‹pqpush› ‹pqpop›`: a binary heap over a `‹vec›`, keyed like A4.
  - It is the next LeetCode family: Dijkstra, merge-k, streaming top-k.
- **O4. A byte-count regression check in the gate.**
  - `test/run2.sh` compiles `bench/leetcode/golf/*` on `gen.py 0.001`
    inputs.
  - It checks their answers against the committed Python outputs.
  - It asserts each solution's byte count is ≤ the number recorded in
    `bench/leetcode/README.md`. A solution may only get shorter.
  - Fast: tiny inputs, under 1 s total.
- **O5. A "LeetCode in Golf" tutorial page.**
  - REFERENCE.md §4 gets three of the solutions (Stock, Trap, Sliding
    Window) in their post-W12 form, output-checked like the other tutorial
    examples.
- **O6. Booleans for output.**
  - `‹tf›` (`f -> “true“/“false“` as a code list), using the comparison
    convention.
  - Small, but Valid Parentheses spends 13 of its 131 bytes on spelling
    them.
- **O7. 2-D helpers (optional).**
  - `‹grid›` (`lines -> rows cols flat`) and `‹nbrs›` (`i -> up to 4 in-range
    neighbour indices`).
  - Only if Islands-type problems keep recurring. Z4 already removes most of
    that solution's bulk.

## 4. Waves

Same method as W11:

- Each task runs in its own worktree from the wave's base.
- Tasks merge in a fixed order, with `test/gate.sh` green after every merge.
- Byte and name allocations happen up front in W12-0, so parallel tasks never
  contend for the same bytes or names.

| Wave | Tasks (parallel unless noted) | Why this order |
|---|---|---|
| **W12-0** (serial, small) | Allocate bytes in REGISTRY.md (below); release the stale `0xD8`–`0xEF` reservation; commit `bench/leetcode` (done in this PR) and `bench/micro`; write A1's contract and its run2 cases | Everything else needs the bytes and the baseline |
| **W12-1** | P1 input · P2 dicts · O1 atoms on lists · Z3 locals a–z | Independent; P1 alone fixes 3 of the 4 losses to Python |
| **W12-2** | P3 tight loops · Z4 store-at, vector, deque | P3 rewrites the loops A2/A3/A5 will copy; Z4 is what A5's deque and O3's heap sit on |
| **W12-3** | A2 scan/reduce · A3 each-indexed · A4 sort-by/grade · A5 window · A6 fixpoint | All prelude words on P3's loop shape |
| **W12-4** | A7 if-else/while (compiler) · Z2 `⇡⇣` (compiler) | Both touch `golf2.golfj` + seed + golfref; same owner, one at a time, or two agents with a fixed merge order |
| **W12-5** | A8 streams · O2 freeable thunks · O3 priority queue | Streams build on P1's incremental parser and A1's contract |
| **W12-6** (serial) | Z1 one-byte aliases (from measured usage) · rewrite `bench/leetcode/golf/*` with the new words · O4 gate check · O5 tutorial · O6 `‹tf›` · numbers in RESULTS.md | Aliases are chosen from real usage after the vocabulary exists |

M7 (P5) follows as its own round.

### Byte allocation for W12-0 (proposal)

| Byte | Glyph | Mnemonic | What | Task |
|---|---|---|---|---|
| `0xB8` | `⋄` | `\else` | compiler op: else / while-body separator | A7 |
| `0xB9` | `⇡` | `\vinc` | compiler op: `⇡x` increments variable x | Z2 |
| `0xBA` | `⇣` | `\vdec` | compiler op: `⇣x` decrements variable x | Z2 |
| `0xD1` | `⍀` | `\scan` | prelude: inclusive scan | A2 |
| `0xD2` | `⍁` | `\reduce` | prelude: seedless fold | A2 |
| `0xD3` | `⍸` | `\eachi` | prelude: map with index | A3 |
| `0xD4` | `⍒` | `\sortby` | prelude: stable sort by key | A4 |
| `0xD5` | `⍈` | `\put1` | prelude: store into a list | Z4 |
| `0xD6` | `⍆` | `\push` | prelude: vector push | Z4 |
| `0xD7` | `⍅` | `\pop` | prelude: vector pop | Z4 |
| `0xD8` | `⊟` | `\win` | prelude: window reduce | A5 |
| `0xD9` | `⍣` | `\fix` | prelude: apply until fixed | A6 |
| `0xDA` | `⍞` | `\next` | prelude: stream next | A8 |
| `0xDB`–`0xE3` | — | — | Z1's aliases, picked in W12-6 | Z1 |

None of these glyphs is in `tools/codepage.py` or `tools/mkblob2.py` today
(checked). W12-0 still runs `codepage.py check` with the rows added
temporarily, as W11-0 did, because mnemonics must stay prefix-free. For
example, `\put1` must not collide with an existing `\put…` mnemonic.

## 5. Risks

- **P3 and the stack-threading contract.** If loop state moves onto the data
  stack, a user function that reaches below its element would see it. The fix
  is to keep the loop state on the return stack or the spill stack, never on
  the user's data stack. A1's run2 cases are the tripwire.
- **Compiler work in A7/Z2.** Every compiler change is made twice (golf2
  and the v1 seed), and selfcheck must stay byte-identical. Keep W12-4
  small, and don't combine it with M7.
- **Prelude size.** The prelude is about 43 KB of the 192 KB cap. This round
  adds an estimated 8–12 KB, so it stays far from the cap.
- **Timing noise.** Speed targets are checked by hand on a quiet machine. Only
  correctness and byte counts gate.

## 6. Open questions for the user

1. Atoms on lists (O1): throw `not a number` (recommended), or vectorize?
2. Is it OK to release the `0xD8`–`0xEF` "chain syntax" reservation for
   prelude words?
3. Should Z1's one-byte aliases replace the long names in the docs and
   examples, or only be offered alongside them?
4. Should M7 (register codegen) come before or after this round? This plan
   assumes after: it makes everything faster, but it is the riskiest change
   to the fixpoint.
