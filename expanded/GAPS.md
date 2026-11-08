# Expanded GOLF — the gaps to Python and Jelly

[`DESIGN.md`](DESIGN.md) records what shipped and the limits we know about;
[`NEXT_STEPS.md`](NEXT_STEPS.md) is the forward queue. This file is the third
question: **measured against the two languages GOLF is explicitly positioned
between, what is actually missing?**

DESIGN.md names both. The vision section wants "a usable minimal language
(Forth/C-flavored)" — that is the Python-shaped half — and "a terse golf surface
(Jelly-flavored)" — that is the Jelly-shaped half. So this is not an arbitrary
comparison; it is the project's own stated targets, audited.

Everything below was **checked against a built compiler**, not read off the
docs. Where a claim is a program, the program is given, and it was compiled with
`tools/golfc -j` and run. Where a gap is already queued, the queue item is
cited; where it is *not* queued, that is called out — those are the useful rows.

---

## 0. The three languages are not trying to do the same thing

| | GOLF/2 | Jelly | Python |
|---|---|---|---|
| Purpose | a self-hosting compiler small enough to read | code golf | general-purpose |
| Implementation | itself — `self/golf2.golf`, ~4.5 KB of its own source | ~thousands of lines of Python + sympy | ~1M lines of C |
| Output | a standalone ELF64 binary, no libc, no linker | interpreted | interpreted |
| Named operations | 62 (32 atoms + 5 compiler ops + 25 library words) | 300+ atoms, plus quicks | ~70 keywords/operators + a vast stdlib |
| Values | one type: a 64-bit machine word | int/float/complex, character, arbitrarily nested list | a full object model |
| Evaluation | explicit concatenative stack | parse-time arity algebra over chains | expression tree |

The counts are the least interesting row. GOLF wins on an axis neither of the
others competes on — it compiles itself to a byte-identical fixpoint and emits
freestanding executables — and the discipline that buys that (one byte per op, a
compiler that must stay small enough to be re-derived) is exactly what produces
most of the gaps below. **Almost nothing here is an oversight. Most of it is the
price of the fixpoint, and worth knowing the size of.**

---

## 1. Gaps to Jelly

Jelly is the closer comparison — GOLF already borrowed the code page, the
one-byte-per-op canon, and the glyph/mnemonic round-trip from it. What did not
come across:

### 1.1 The data model — nested lists (support shipped, W9-3B)

**Jelly's central data structure is the arbitrarily nested list.** Every atom
that touches a list is defined at every depth, and arithmetic vectorizes all the
way down. Until W9-3B GOLF had *one* level and nothing below it: `⍕` printed
inner lists as raw heap addresses, and M-VEC's five operators dispatched on the
shapes of their two operands once, never recursing into elements.

A GOLF list is a heap block `[len, e0, …]` of 64-bit cells, and an inner list is
a tagged value (`addr | 0x7FFF<<48` since W11-1A; `addr | 2^48` from M-TAG2), so "is this element a list?" is an exact
shift-and-compare. W9-3B asks it of every element:

```
3⍳′⍳€⍕         ->  [] [0] [0 1]          # recursive show; flat lists unchanged
3⍳′⍳€ 10+⍕     ->  [] [10] [10 11]       # + - * ⌈ ⌊ recurse to any depth
3⍳′⍳€"≣Ṅ       ->  -1                    # structural equality
3⍳′⍳€⍤Ṅ        ->  2                     # depth
```

What is still missing against Jelly: the rest of the list vocabulary is
one-level (`∑` folds with the deep `+`, but `⌽`, `⌿`, `⊇` see only the top
level), there is no rank or reshape, and `Z` truncates silently on a length
mismatch at every depth. Nesting depth is bounded by the scratch spill stack —
4096 frames since W10-C (it was 28), so ~2,000 levels of nested arithmetic and
~4,000 of `⍕`/`≣`/`⍤`, past which `X` exits with `GOLF: spill stack
exhausted` (DESIGN.md, known limits).

### 1.2 The numeric tower

Jelly has arbitrary-precision integers, floats, and complex numbers. GOLF has
one type, and it wraps:

```
9223372036854775807⊕Ṅ  ->  -9223372036854775808     # silent 64-bit wrap
7 2÷Ṅ                  ->  3                        # truncating; no rationals
```

No floats, no bignums, no complex, no rationals — and no *characters* either.
Jelly distinguishes a character from an integer, which is how it prints
`"abc"` as text and `[97,98,99]` as numbers from the same list machinery. GOLF
cannot: `⊃` turns a byte block into a code list and `⊐` prints a code list back,
and the choice of which to use is the programmer's, every time. There is no
value that knows it is text.

This one is a **deliberate, load-bearing** choice, not an omission: "every value
is a 64-bit machine word" is why an atom can be a raw one-instruction template,
which is why the template blob is 714 bytes, which is why the compiler fits.
Floats would mean an SSE calling convention in every arithmetic template; bignums
would mean an allocator on the arithmetic path. Both would end the aesthetic
DESIGN.md is protecting. Worth stating as a *decision* in DESIGN.md rather than
leaving it implied.

### 1.3 The vocabulary

Jelly's ~300 atoms cover sorting, grouping, uniquifying, permutations, base
conversion, primality, gcd, matrix ops, string ops, date handling. GOLF's list
vocabulary is 17 words: range, sum, len, index, alloc, map, fold, show, product,
reverse, filter, puts, chars, join, zip, plus the five polymorphic operators and
three combinators.

Missing and routinely needed *was*: **slice, index-of, unique, min/max of a
list, structural equality, flatten**. Concatenate used to head this list —
`+` on two lists is elementwise, so there was no way to join two lists at all —
and **W9-4A shipped it** as `⧺` (with `↑` take and `↓` drop, negative `n`
counting from the end); **W9-4B shipped sort and member** as `⍋` (a new list,
ascending signed, stable merge sort) and `∊` (`list x -> 0` on a hit, 1 on a
miss); W9-3B shipped structural equality as `≣`; and **W9-4B part 2 shipped
the rest** as long-named prelude words — `‹slice›`, `‹indexof›`, `‹unique›`
and `‹flatten›`. So none of sort, concatenate, take, drop, slice, member,
index-of, unique, structural equality or flatten is missing any more. Of the
list above only min/max of a list has no word of its own; it is a fold
seeded with the first element, `"0⊇′⌈⇤` (`′⌊` for the min):

```
2⍳2⍳+⍕   ->  0 2        # elementwise, not [0,1,0,1]
2⍳2⍳⧺⍕   ->  0 1 0 1    # W9-4A: concatenate
5⍳⌽⍋⍕    ->  0 1 2 3 4  # W9-4B: sort
5⍳3∊Ṅ    ->  0          # W9-4B: member (zero-is-true)
5⍳1 3‹slice›⍕  ->  1 2 3        # W9-4B part 2: slice
5⍳3‹indexof›Ṅ  ->  3            # W9-4B part 2: index-of (-1 if absent)
5⍳"⧺‹unique›⍕  ->  0 1 2 3 4    # W9-4B part 2: unique, first occurrences
3⍳′⍳€‹flatten›⍕ -> 0 0 1        # W9-4B part 2: flatten
3⍳3⍳≡Ṅ   ->  0          # ≡ compares the two ADDRESSES, not the contents
```

The blocker is named in [`REGISTRY.md`](REGISTRY.md) §2 and it is real: the
prelude's uppercase pool is down to `B` and `C`. Two letters, ten-plus wanted
words. Everything else has to come from `0xC8`–`0xCF` (eight bytes) or wait for
M2 multi-character identifiers (§4 of the queue). **This makes M2 more urgent
than its current position suggests** — it is filed as "nothing above needs it",
but the library cannot grow past two more words without it. *(Since W9-3A:
**shipped** — `‹name›` long names, so the blocker is gone; and since W9-4B
part 2 the library words themselves are written, as long-named words.)*

### 1.4 Tacit programming: runtime library vs parse-time algebra

Both languages are tacit-flavored, but by completely different mechanisms, and
the difference is bigger than it looks.

Jelly's chains are a **parse-time arity algebra**. Every atom has a known arity;
the parser threads arguments through a chain by pattern-matching on those
arities, and quicks (`€ / \ ¡ ¿ ð µ ¥ $ ¤`) are parse-time combinators that
restructure the chain before anything runs. That is where Jelly's compression
actually comes from — far more than from single-byte atoms.

GOLF has no concept of arity anywhere. Words are variadic by stack discipline
and nothing checks them — a word that under-pops silently eats its caller's
values. Its combinators are **ordinary runtime library words**: `∘` compose
literally assembles 39 bytes of machine code into an RWX arena and returns the
address; `€` map and `⇤` fold are plain words that need an explicit `′`
quotation. `⊚` chain definitions ([M-CHAIN2](DESIGN.md)) are the one parse-time
piece, and they are sugar over a fixed shape table (1 link = call, 2 = atop,
3 = fork, n>3 = fork then the rest), not an algebra.

The practical consequence: `⊞` zip exists *because* only five operators carry a
shape hook, so every other binary function still needs the explicit spelling.
Jelly needs no such escape hatch. Closing this properly is a front-end rewrite,
not a milestone — worth recording as out of scope rather than leaving it as an
implied someday.

### 1.5 I/O and the program's shape — input shipped (W9-4C)

Jelly reads arguments from the command line, evaluates the last chain as `main`,
and **auto-prints the result**. GOLF requires explicit printing every time
(`Ṅ ⍕ ␤ 🗲 ⊐`). Until W9-4C an ordinary user program also had almost nothing
to read *with*: `(` got one byte from stdin, and that was the whole input
surface (`lib/tio.golfj`/`lib/ttext.golfj` serve only the repo's own tools).

W9-4C (NEXT_STEPS item 5, M6b) put the input half into the prelude under long
names, so no letter was spent: `‹readall›`, `‹readline›`, `‹getc›`,
`‹words›`, `‹num›`, `‹ints›` and `‹args›` (REFERENCE.md, "Input").
`printf '1 2 3' | prog` with `‹ints›∑Ṅ` prints `6`. What remains of the gap is
the program's *shape*: no implicit `main`, no auto-print, and the command line
arrives as code lists the program must parse itself (`‹args›′‹num›€`).

**Closed (W11-1C): output was one `write(2)` per byte.** Python buffers
stdout; GOLF's printers made a system call for every byte, so `1000000⍳⍕` cost
6,888,890 writes (0.75 s). They now share an 8 KB buffer with `‹flush›`,
drained at every exit, before every `GOLF:` message, before the input words
read, and before a raw `)` or `(`: 841 writes (0.07 s), the same bytes
(REFERENCE.md, "Output"; DESIGN.md, known limits).

---

## 2. Gaps to Python

Jelly is the aspirational peer; Python is the "you'd actually write programs in
it" target from DESIGN.md's vision. The distance is much larger, and mostly
uncontroversial.

### 2.1 Data structures

One aggregate type: the flat list of 64-bit cells. **No dict, no set, no tuple,
no object, no class.** No dict is the sharpest of these — it is the data
structure that makes most Python programs short, and GOLF has no hashing
primitive to build one on. Strings are not values (§1.2); there is nothing to
key on but integers.

### 2.2 Names and scope

- **Single-byte identifiers.** 256 word slots in a flat byte-indexed table, and
  the readable letters are gone (§1.3). **Fixed by M2 (W9-3A):** `‹name›` adds
  long names, usable as words, quotations, chain links, variables and (since
  W9-4D) locals — 256 per program at first, 1024 since W10-A.
- **No lexical scope, and no closures.** The variable bank is one global cell per
  name. The "closure" idiom in `examples/legacy_capstone.golfj`
  (`10→k:f←k+;… ′f€`) is a global read at call time, not a capture:

  ```
  10→k :f←k+; 3⍳′f€⍕   99→k   3⍳′f€⍕
  ->  10 11 12  99 100 101       # f follows k; nothing was captured
  ```

- **Recursion with `→x` is silently wrong** — the bank is global, so a recursive
  word shares one cell across every frame:

  ```
  :f"0-[_0^]→n←n1-f←n+;3fṄ   ->  3        # should be 6 (3+2+1)
  ```

  A *silent wrong answer*, not a crash, which made it the highest-severity item
  in the queue for anyone actually writing programs. **Fixed by M-FRAME**, opt in
  per definition: `⊡f"0-[_0^]⇒a⇐a1-f⇐a+;3fṄ` is `6`. The global spelling still
  behaves exactly as above — it is not deprecated, and the suite pins both.
  Since M-FRAME2 (W9-4D) locals may have long names (`⇒‹acc›`) and a frame
  is sized to the locals a word names, one cell each — the `^`s' frame-size
  immediates are patched at `;` ([`NEXT_STEPS.md`](NEXT_STEPS.md) §2).

### 2.3 Functions

No parameters (arguments arrive on the stack), no return type, no default or
keyword arguments, no varargs, **no arity checking of any kind**, no anonymous
functions — `′` quotes a *named* word, so every function must be defined and
named first — and no generators, decorators, or comprehensions.

**No forward references or mutual recursion.** *(Fixed for long names by M2,
W9-3A: a `‹name›` may be called or quoted before its definition, the call sites
are patched when it arrives, and one never defined is `GOLF: undefined word
‹name›`, exit 2. **Fixed for one-byte names by W10-A**, the same way:
`:a"0-[_0^]1-b;:b"0-[_1^]1-a;5aṄ` prints `1`, and a name never defined is
`GOLF: undefined word b` at end of input. What follows is the history.)* A
word had to be defined before use.
Self-recursion works (the dictionary slot is live inside the body), but two words
that call each other cannot be written at all — and the failure is a compile that
*succeeds* and a binary that segfaults:

```
:a"0-[_0^]1-b; :b"0-[_1^]1-a; 5aṄ     ->  compiles clean, SIGSEGV at run time
```

An undefined name compiles to a call through an empty dictionary slot. This is
**not in the queue anywhere** — M2 (§4) mentions "two-pass or forward-declaration
handling" in passing as an implementation note, but the defect itself is
unrecorded. A one-line fix is available independently of M2: have the compiler
emit a diagnostic for a call to an unfilled dictionary slot instead of emitting
a jump to zero.

### 2.4 Errors

There is no error handling and no error *reporting* — not a `try`, and not a
message. Every failure mode is silent corruption or a signal:

```
7 0÷Ṅ      ->  SIGFPE (rc 136)          # divide by zero
3⍳9⊇Ṅ      ->  0                        # out of bounds, no check, garbage back
```

**Since W9-2B, both of those two are reported**: `GOLF: divide by zero` /
`GOLF: index out of range` on fd 2, exit status 1 (`∣` too, and a negative or
exactly-`len` index; `INT64_MIN ÷ -1` is defined as `INT64_MIN`, `∣ -1` as 0).
Still a signal: v1's unsigned `/` and `%` divided by zero — they are frozen v1
templates. Still no `try`; a runtime error ends the program.

The compiler is the same: bad source does not produce a diagnostic, it produces
a bad binary. For a language whose whole test discipline is byte-identical
differential comparison, "no diagnostics at all" is a defensible cost — but it is
the single biggest difference in *what it feels like* to write GOLF versus
Python, and it appears nowhere in DESIGN.md's limits.

### 2.5 Memory

- **Freeing is manual (was: nothing is freed).** `A` bump-allocated and `M`,
  `W`, `V`, `Z`, `K`, `G` each allocate per call, so a map in a loop climbed
  forever. **Since W9-3C (M-MEM2)** `⌫` hands a block back to a size-classed
  free list that `A` checks first, so a loop that frees what it maps keeps the
  break flat. It is explicit — nothing frees on its own, there is no GC and no
  ownership, and a use after `⌫` is undefined — so against Python this is
  C's `free`, not reference counting.
- **The `∘` compose arena has no bounds check, and overruns into user data.**
  See §3 below — this one is a live defect, not a design limit.

### 2.6 Everything around the language

No modules or imports (`include` is listed under "as needed", M9), no standard
library beyond the prelude, no package ecosystem, no REPL, no debugger, no
introspection, no threads or async, and one target: x86-64 Linux, ELF64,
statically laid out. A retargetable IR is also M9.

---

## 3. Defects found while writing this

Three, none of them recorded anywhere in the repo when this file was written.
All were reproduced against a compiler built by `tools/golfc`. **The first two
are now fixed** — the descriptions below are kept as the record of what the
behaviour was, each with its resolution. The third is now queued.

### 3.1 `∘` overran its arena into the user variable bank — FIXED

[`REGISTRY.md`](REGISTRY.md) §3 documents the code arena as
`0x4D0000`–`0x4DFFFF`, "1680 thunks; never freed". **Nothing enforces the upper
bound.** `0x4D0000 + 39 × 1681 = 0x4E0017`, which is inside the user variable
bank at `0x4E0000` — so the 1681st `∘` starts writing machine code over
`→x`/`←x` cells, and the program keeps running:

```
1234→v 0{′⊕′⊗∘_ 1﹢"1700﹤1+}_ ←vṄ   ->  1234                    # fine
1234→v 0{′⊕′⊗∘_ 1﹢"2000﹤1+}_ ←vṄ   ->  -13230423417028608      # clobbered
```

The thunks stayed callable and the program exited 0; only the variables were
destroyed, silently. Note this is *not* M-MEM2: that item is about the list heap
allocator `A`. This is a different arena with a different failure mode — data
corruption rather than growth.

**Fixed.** `∘` now tests the bump pointer before it writes: `65536 - 39 = 65497`
is the last legal offset, so an offset of 65498 or more writes
`GOLF: compose arena exhausted` to fd 2 and exits 1 rather than wrapping into
user data. 1680 composes still succeed, the 1681st dies, and `run2.sh` pins both
ends plus the canary variable. Growing the arena with `brk` instead was
considered and rejected: `brk` memory is not executable, and thunks are code.
Nothing can be freed either — a thunk's address may have escaped anywhere — so
stopping is the only honest answer.

### 3.2 An undefined word compiled to a jump to zero — FIXED

§2.3. Compile succeeded, binary segfaulted, no diagnostic. This was the
mechanism that made mutual recursion impossible *and* made any typo in a word
name a runtime crash with no clue attached.

**Fixed.** Both compilers now test `dict[name]` before emitting `call rel32` and
exit 2 when it is zero; `golf2` also writes `GOLF: undefined word <name>` to
fd 2. Neither leaves a partial binary on fd 1. The check cost the reordering of
two ops — `232o` moved below the lookup so the slot could be tested before a
byte was written — and `rel32` is unchanged, so the fixpoint and the
byte-for-byte `seed == golf2` agreement both hold.

One asymmetry, deliberate and gated by `selfcheck.sh`: the seed exits 2 without
a message. It cannot do otherwise — `seed.golf`'s source is v1 GOLF, compiled by
the frozen `v1c`, whose entire output surface is `)` (one byte to fd 1) and `.`
(exit), and fd 1 is carrying the binary. The two agree on the decision and the
status; only the explanation is golf2's, and the seed's error path is unreachable
in the build anyway.

*A different bug, fixed later (W9-1C):* the `′` path did not get this check.
`X` treated a name with no dictionary entry as an **atom** (that is how `′atom`
auto-wrapping works), so `′typo` built a thunk around a template that does not
exist, and `3⍳′q€⍕` compiled clean and died with SIGILL. `X` now also checks the
blob and hands a byte that is neither word nor atom to `e`, which is already the
diagnostic: `GOLF: undefined word q`, exit 2, nothing on fd 1 (the seed exits 2
silently, as above). Chain links go through `X`, so they are covered too.

### 3.3 Nested lists had no support above the storage layer — FIXED (W9-3B)

§1.1. Not a crash, but `⍕` printing pointers was a wrong answer, and it was the
gap that most limited what could be written. The tag bit (M-TAG2, W9-2A) was its
prerequisite; W9-3B then made `⍕` recursive, made the bare `+ - *` recurse like
`⌈ ⌊`, and added `≣` (structural equality) and `⍤` (depth).

### 3.4 Integers in `[2^48, 2^49)` were lists — FIXED (W11-1A)

M-TAG2's tag was bit 48 (`addr | 2^48`), so every integer from 281 to 562
trillion was shape-tested as a list: `16777216 16777216* 1+Ṅ` segfaulted, and a
sum of squares such as `100000⍳"*∑Ṅ` broke once it passed 2^48. W11-1A moved the
tag to the top 16 bits `0x7FFF` (`addr | 0x7FFF<<48`); both programs now print
`281474976710657` and `333328333350000`. The band sacrificed is now
`[0x7FFF<<48, 2^63)` — the 2^48 integers just below `INT64_MAX` (DESIGN.md, known
limits); negatives (top bits `0xFFFF`) stay ints as before.

Already recorded and confirmed accurate: the `T` range-test misclassification
(queue §1 — **fixed** by M-TAG2, W9-2A), the global-bank recursion footgun (queue §2),
allocator leaks (queue §3), the letter shortage (REGISTRY §2), and the
seed/golf2 divergence above 2³¹ (DESIGN.md known limits).

---

## 4. What GOLF has that neither of them does

Worth stating, because the gaps above are all one-directional by construction:

- **It compiles itself to a byte-identical fixpoint.** Neither CPython nor Jelly
  is written in itself; Jelly is a Python program and needs Python and sympy to
  run at all.
- **It emits freestanding ELF64 binaries** — no libc, no linker, no assembler, no
  runtime. `hello` is a complete executable.
- **The whole compiler is readable in one sitting**, and the bootstrap ladder is
  reproducible from a single Python file.
- **Every allocation of every scarce resource is written down before it is used**
  (REGISTRY.md), and the documentation's numbers are asserted by the test suite.
  Neither comparison language has anything like that discipline.

---

## 5. Deltas to the queue — all five applied

Ordered by (severity × how cheap the fix is) when this file was written.
[`NEXT_STEPS.md`](NEXT_STEPS.md) remains the queue of record.

1. **Bound the `∘` arena** (§3.1) — **done.** Silent corruption of user data, and
   the fix was a compare-and-die in one prelude word.
   `lib/prelude.golfj`; four assertions in `run2.sh`.
2. **Diagnose an undefined word** (§3.2) — **done.** Turns every name typo, and
   every attempt at mutual recursion, from a segfault into a message that names
   the byte. `self/golf2.golfj` + `mkblob2.py`'s v1-GOLF seed; six assertions in
   `run2.sh` and three in `selfcheck.sh`.
3. **Record the nested-list gap, and make it the second justification for the tag
   bit** (§1.1) — **done.** [`NEXT_STEPS.md`](NEXT_STEPS.md) §1 now carries it:
   the tag bit is the prerequisite for depth, rank, recursive `⍕` and deep
   vectorization, not only the fix for a misclassification.
4. **Reconsider M2's position** (§1.3) — **done.** Its "nothing above needs it"
   is retired: with two uppercase letters left, every remaining library word and
   M6b are gated behind it, and it is now sequenced after the tag bit rather than
   last.
5. **Add a "deliberate non-goals" section to DESIGN.md** (§1.2, §1.4, §2.4) —
   **done.** The numeric tower, arity and general diagnostics are recorded as
   refused, with the reason, so they read as decisions rather than omissions.

Since then **M-FRAME** shipped too, which was §2.2's silent-wrong-answer on
recursion — the worst remaining defect this file found. That leaves, as the top
of the real queue: the tag bit (correctness *and* nested data), then M2 (the
letter shortage — since shipped by W9-3A), then sizing a `⊡` frame per
definition — since shipped, with named locals, by W9-4D. Two small unclaimed fixes remain: the
`′`-path variant of §3.2, and a guard on the return stack, which M-FRAME made
easier to reach — since closed by W9-2C's guard page (DESIGN.md, known limits).
