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

### 1.1 The data model — the big one, and it is not on the queue

**Jelly's central data structure is the arbitrarily nested list.** Every atom
that touches a list is defined at every depth, and arithmetic vectorizes all the
way down. GOLF has *one* level and nothing below it:

```
2⍳′⍳€1+⍕      ->  <addr> <addr>      # wanted [[1],[1,2]]; got the addresses, +1
3⍳′⍳€⍕        ->  <addr> <addr> …    # ⍕ prints the inner lists' addresses
```

(The printed values are heap addresses, so they are ASLR-shifted and differ every
run — which is itself the tell: they are pointers, not data.)

A GOLF list is a heap block `[len, e0, …]` of 64-bit cells and an element is
just a cell. Nesting *stores* fine — the inner lists are really there — but
nothing in the language knows it:

- `⍕` (show) prints one level and renders inner lists as raw pointers.
- M-VEC's five polymorphic operators dispatch on the shapes of their two
  operands, once. They do not recurse into elements.
- `T` cannot tell "list of ints" from "list of lists"; there is no depth or rank
  anywhere in the representation.

This is the single largest gap to Jelly, and unlike the tag bit
([`NEXT_STEPS.md`](NEXT_STEPS.md) §1) **it is not in the queue at all.** Note the
dependency: a recursive `⍕`, or vectorization to arbitrary depth, needs to ask
"is this cell a list?" of *every element* — which is precisely the question `T`
answers with a range heuristic that DESIGN.md admits is wrong in principle. So
the tag bit is not just a correctness fix; it is the prerequisite for the whole
nested-data story. That is worth saying explicitly in the queue, because item 1
is currently justified only by the misclassification bug.

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

Missing and routinely needed: **sort, concatenate, take/drop/slice, member,
index-of, unique, min/max of a list, structural equality, flatten**. Concatenate
is the one that stings most — `+` on two lists is elementwise, so there is no way
to join two lists at all:

```
2⍳2⍳+⍕   ->  0 2        # elementwise, not [0,1,0,1]
3⍳3⍳≡Ṅ   ->  0          # ≡ compares the two ADDRESSES, not the contents
```

The blocker is named in [`REGISTRY.md`](REGISTRY.md) §2 and it is real: the
prelude's uppercase pool is down to `B` and `C`. Two letters, ten-plus wanted
words. Everything else has to come from `0xC8`–`0xCF` (eight bytes) or wait for
M2 multi-character identifiers (§4 of the queue). **This makes M2 more urgent
than its current position suggests** — it is filed as "nothing above needs it",
but the library cannot grow past two more words without it.

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

### 1.5 I/O and the program's shape

Jelly reads arguments from the command line, evaluates the last chain as `main`,
and **auto-prints the result**. GOLF requires explicit printing every time
(`Ṅ ⍕ ␤ 🗲 ⊐`) and, for an ordinary user program, has almost nothing to read
*with*: `(` gets one byte from stdin, and that is the whole input surface.

The pieces exist — `⎈` (`\sys`) is an atom available to any program, and
`lib/tio.golfj`/`lib/ttext.golfj` have buffered reads, a slurp, argv and decimal
parsing — but those libraries are prepended only by `gtools/build`, for the
repo's own tools. This is queued as item 5 (M6b) and correctly scoped there;
the note that it cannot simply prepend `lib/t*.golfj` (they claim `a`–`z`
wholesale) is the crux, and it runs into the same letter shortage as §1.3.

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
  the readable letters are gone (§1.3). Queued as M2 (§4).
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

  This is queued as M-FRAME (§2) and correctly described. Worth noting it is a
  *silent wrong answer*, not a crash, which makes it the highest-severity item
  in the queue for anyone actually writing programs.

### 2.3 Functions

No parameters (arguments arrive on the stack), no return type, no default or
keyword arguments, no varargs, **no arity checking of any kind**, no anonymous
functions — `′` quotes a *named* word, so every function must be defined and
named first — and no generators, decorators, or comprehensions.

**No forward references or mutual recursion.** A word must be defined before use.
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

The compiler is the same: bad source does not produce a diagnostic, it produces
a bad binary. For a language whose whole test discipline is byte-identical
differential comparison, "no diagnostics at all" is a defensible cost — but it is
the single biggest difference in *what it feels like* to write GOLF versus
Python, and it appears nowhere in DESIGN.md's limits.

### 2.5 Memory

- **Nothing is freed.** `A` bump-allocates; `M`, `W`, `V`, `Z`, `K`, `G` each
  allocate per call, so a map in a loop climbs forever. Queued as M-MEM2 (§3),
  accurately.
- **The `∘` compose arena has no bounds check, and overruns into user data.**
  See §3 below — this one is a live defect, not a design limit.

### 2.6 Everything around the language

No modules or imports (`include` is listed under "as needed", M9), no standard
library beyond the prelude, no package ecosystem, no REPL, no debugger, no
introspection, no threads or async, and one target: x86-64 Linux, ELF64,
statically laid out. A retargetable IR is also M9.

---

## 3. Defects found while writing this

Three of these are unrecorded anywhere in the repo. All were reproduced against
a compiler built by `tools/golfc`.

### 3.1 `∘` overruns its arena into the user variable bank (unrecorded)

[`REGISTRY.md`](REGISTRY.md) §3 documents the code arena as
`0x4D0000`–`0x4DFFFF`, "1680 thunks; never freed". **Nothing enforces the upper
bound.** `0x4D0000 + 39 × 1681 = 0x4E0017`, which is inside the user variable
bank at `0x4E0000` — so the 1681st `∘` starts writing machine code over
`→x`/`←x` cells, and the program keeps running:

```
1234→v 0{′⊕′⊗∘_ 1﹢"1700﹤1+}_ ←vṄ   ->  1234                    # fine
1234→v 0{′⊕′⊗∘_ 1﹢"2000﹤1+}_ ←vṄ   ->  -13230423417028608      # clobbered
```

The thunks stay callable and the program exits 0; only the variables are
destroyed, silently. Note this is *not* M-MEM2: that item is about the list heap
allocator `A`. This is a different arena with a different failure mode — data
corruption rather than growth — and it needs its own row. The cheap fix is a
bounds check in `∘` that dies rather than wrapping; the real fix is that the
arena should be `brk`-grown like the list heap was at M-MEM.

### 3.2 An undefined word compiles to a jump to zero (unrecorded)

§2.3. Compile succeeds, binary segfaults, no diagnostic. This is the mechanism
that makes mutual recursion impossible *and* makes any typo in a word name a
runtime crash with no clue attached.

### 3.3 Nested lists have no support above the storage layer (unrecorded)

§1.1. Not a crash, but `⍕` printing pointers is a wrong answer, and it is the
gap that most limits what can be written.

Already recorded and confirmed accurate: the `T` range-test misclassification
(DESIGN.md known limits, queue §1), the global-bank recursion footgun (queue §2),
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

## 5. Suggested deltas to the queue

Ordered by (severity × how cheap the fix is), and stated as suggestions —
[`NEXT_STEPS.md`](NEXT_STEPS.md) remains the queue of record.

1. **Bound the `∘` arena** (§3.1). Silent corruption of user data, and the fix is
   a compare-and-die in one prelude word. Should not wait behind anything.
2. **Diagnose an undefined word** (§3.2). Turns every name typo from a segfault
   into a message, and unblocks nothing else — but it is small and it is the
   first thing a new user will hit.
3. **Record the nested-list gap, and make it the second justification for the tag
   bit** (§1.1). Item 1 of the queue is currently sold on correctness alone; it
   is also the prerequisite for depth, rank, recursive `⍕`, and deep
   vectorization. That reframing probably moves it up rather than changing it.
4. **Reconsider M2's position** (§1.3). It is filed as "nothing above needs it",
   but with two uppercase letters left, the library cannot grow past two more
   words — so M6b (§5) and every list word in §1.3 are gated behind it.
5. **Add a "deliberate non-goals" section to DESIGN.md** for the numeric tower
   (§1.2), arity checking (§1.4), and diagnostics (§2.4). All three are currently
   *implied* decisions; a reader comparing GOLF to Jelly cannot tell whether they
   are unbuilt or refused, and they are refused for good reasons.
