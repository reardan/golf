# Benchmark results, one row per wave

`leetcode/bench.sh in` (wall seconds, best of 3, large inputs) and
`micro/micro.sh` (ns per element, `⍳` included). Bytes from
`leetcode/bytes.sh`. The machine is a shared cloud container, so compare
rows taken on the same day and treat ±15% as noise.

## LeetCode, Golf seconds (Python / C++ for reference on the first row)

| Wave | twosum | parens | stock | longsub | prodself | topk | islands | trap | slidemax | queens | Golf bytes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| baseline (main after #16), 2026-11-08 | 0.293 | 0.147 | 0.566 | 0.142 | 0.411 | 0.564 | 0.089 | 0.620 | 0.633 | 0.022 | 898 |
| Python, 2026-11-08 | 0.096 | 0.155 | 0.235 | 0.349 | 1.175 | 0.087 | 0.559 | 0.292 | 1.406 | 0.169 | 2,571 |
| C++ -O2, 2026-11-08 | 0.063 | 0.019 | 0.032 | 0.009 | 0.080 | 0.032 | 0.019 | 0.059 | 0.097 | 0.012 | 4,613 |
| W12-Z4, 2026-11-08 | 0.141 | 0.149 | 0.132 | 0.102 | 0.152 | 0.450 | 0.117 | 0.184 | 0.289 | 0.021 | 851 |

W12-Z4 rewrote parens, islands and slidemax on `⍆ ⍅ ⍈` and the deque
instead of raw `⍶`/`⊛` stacks: 131 → 113, 158 → 131 and 127 → 125 bytes
(898 → 851 for all ten). They are slower, because
each push, pop, peek and `⊇` is now a checked prelude call where the old
code had four or five inline ops. Old and new on the same inputs, best of 5,
same session: parens 96 → 137 ms, islands 67 → 130 ms, slidemax 208 → 294 ms.
| W12-P3 before (base 7a867ca), 2026-11-08 | 0.139 | 0.120 | 0.096 | 0.086 | 0.171 | 0.448 | 0.073 | 0.189 | 0.199 | 0.024 | 898 |
| W12-P3, 2026-11-08 | 0.129 | 0.097 | 0.082 | 0.080 | 0.126 | 0.440 | 0.061 | 0.107 | 0.202 | 0.020 | 898 |
| W12-A7, 2026-11-08 | 0.069 | 0.112 | 0.070 | 0.075 | 0.131 | 0.094 | 0.100 | 0.117 | 0.248 | 0.024 | 815 |

W12-A7 rewrote two solutions with `⋄`: parens ends `[“true“⋄“false“]🗲`
(113 → 111 bytes) and queens' column loop is a top-tested `{⇐v0≡⋄…}` in place
of a `[0^]` guard plus a bottom test (110 → 106); 821 → 815 for all ten.
Outputs match the old binaries and Python. Old and new on the same inputs,
best of 7, same session: queens 17–20 → 18–22 ms, parens 115–123 → 116–122 ms,
i.e. noise (the while form costs one `jmp` per pass).
| W12-Z2, 2026-11-08 | 0.078 | 0.128 | 0.080 | 0.082 | 0.132 | 0.096 | 0.104 | 0.102 | 0.281 | 0.025 | 772 |

W12-Z2 rewrote four counters with `⇡` (`inc qword [cell]`, no stack traffic):
twosum `←i⊕"→i` → `⇡i←i` (89 → 87), longsub the same (62 → 60), islands
`←c⊕→c` → `⇡c` (131 → 128) and slidemax `←i⊕→i` → `⇡i` (125 → 122); 782 →
772 for all ten (the base had 782 after the merges since A7's row).
Outputs match the old binaries and Python. Old and new on the same inputs,
best of 7, same session: twosum 71 → 71 ms, longsub 70 → 80, islands 108 →
89, slidemax 228 → 236, i.e. noise either way.
| W12-6 before (base 072cdca), 2026-11-08 | 0.075 | 0.125 | 0.108 | 0.081 | 0.141 | 0.092 | 0.103 | 0.130 | 0.185 | 0.032 | 655 |
| **W12 final** (W12-6), 2026-11-08 | 0.072 | 0.115 | 0.080 | 0.085 | 0.136 | 0.091 | 0.111 | 0.116 | 0.175 | 0.025 | 411 |
| Python, same runs as W12 final | 0.121 | 0.142 | 0.253 | 0.340 | 1.202 | 0.108 | 0.560 | 0.301 | 1.221 | 0.209 | 2,571 |
| W13-G before (base 9b14c93), 2026-11-08 | 0.053 | 0.098 | 0.063 | 0.073 | 0.106 | 0.069 | 0.085 | 0.092 | 0.143 | 0.017 | 411 |
| W13-G, 2026-11-08 | 0.053 | 0.097 | 0.065 | 0.073 | 0.107 | 0.067 | 0.084 | 0.090 | 0.143 | 0.018 | 411 |

W12-6 rewrote all ten with the W12 vocabulary and Z1's one-byte aliases
(`ℤ ⎕ ⏎ Ḋ Ġ Ṗ Ḳ Ḃ Ṿ`): 655 → 411 bytes. Stock is `ℤ"′⌊⍀-′⌈⍁Ṅ` and Trap
`ℤ"′⌈⍀&⌽′⌈⍀⌽⌊\\-∑Ṅ` (scan and reduce in place of threaded `€`/`⇤` words),
topk folds `′Ḃ` over the input with `⇤` and keys the sort by the dict
left under the keys, twosum is a `⍸` word, parens a sentinel stack threaded
under `€` (no early-exit, no empty check), queens keeps its count and its
low bit on the stack, islands counts under `⍸`. The W12 final row is the
better of two `bench.sh in` runs (each best of 3); the before row is one
run at the start of the same session. Every problem beats Python, and
interleaved A/B runs of old and new binaries (best of 7 and 11) put every
difference within the ±15% noise (islands 86 → 90–106 ms, from copying the
grid once with `⧺`, is the largest).

## Micro, ns per element

| Wave | loop | iota | sum | map | fold | filter | vadd | dictput |
|---|---|---|---|---|---|---|---|---|
| W12-0, 2026-11-08 | 1.12 | 8.33 | 20.43 | 24.33 | 21.61 | 25.74 | 39.69 | 555.32 |
| W12-O1, 2026-11-08 | 1.12 | 9.24 | 19.77 | 24.08 | 21.54 | 25.18 | 41.15 | 552.18 |
| W12-P3 before (base 7a867ca), 2026-11-08 | 1.05 | 8.70 | 19.77 | 25.12 | 21.31 | 26.64 | 40.53 | — |
| W12-P3, 2026-11-08 | 1.01 | 6.96 | 10.52 | 15.59 | 11.61 | 15.00 | 17.97 | — |
| **W12 final** (W12-6), 2026-11-08 | 1.09 | 7.10 | 11.19 | 15.83 | 15.60 | 17.27 | 18.68 | 164.08 |
| W13-G before (base 9b14c93), 2026-11-08 | 0.83 | 5.41 | 9.22 | 13.96 | 11.04 | 12.50 | 16.12 | 90.43 |
| W13-G, 2026-11-08 | 0.82 | 6.13 | 9.46 | 13.82 | 8.84 | 12.80 | 16.02 | 92.47 |

The W12 final run's other `cases.txt` rows, in ns per element: inc2 1.78,
dictbump 128.44, scan 17.60, reduce 13.70, eachi 18.94, sort 708.46, ksort
604.48, grade 739.22.

W12-O1 put a not-a-number check in front of `± ⊕ ⊖ ² ⊗ ⊘`, and `loop` uses
`⊖`, so its row above is noise-level against W12-0. The A/B below is the
measured cost. Each program was compiled twice with the oracle, with and
without the check, and the two were run interleaved, best of 11, on
10^8 iterations:

| program | without | with | cost per checked op |
|---|---|---|---|
| `loop` `{⊖"0≡}` (1 op) | 0.69–0.85 ns | 0.85–1.02 ns | +0.16 to +0.17 ns |
| `inc2` `{⊕⊖⊖"0≡}` (3 ops; new micro case) | 1.20 ns | 1.46–1.83 ns | +0.08 to +0.21 ns |
| `{±±⊖"0≡}` (3 ops) | 1.01 ns | 1.54 ns | +0.18 ns |

`inc2` was 1.12 ns per element before the check and 1.78–1.89 ns after it
in `micro.sh`.

W12-P3 rewrote the list-word loops (median of three interleaved micro.sh runs
per side above; the leetcode rows are best of two `bench.sh in` runs). The
micro rows are dominated by memory: a fresh 10^7-cell list costs about
3.3 ns/element in page faults alone on this machine (a loop that only stores
one cell per 4 KB page), so `iota` cannot reach the plan's 4 ns. The words'
own cost, on a cache-resident 10^5-element list (best of 11, 200 passes),
and their instructions per element (cachegrind, 10^4 elements):

| word | cached ns/el before → after | instr/el before → after |
|---|---|---|
| `⍳` | — → 2.6–3.1 | 55 → 17.6 |
| `∑` | 11.6 → 1.7–2.1 | 101 → 19.8 |
| `∏` | — → 1.8 | 103 → 21.8 |
| `€` (empty fn) | 12.6 → 3.9–4.3 | 117 → 56 |
| `⇤` | — → 3.9–5.0 | 112 → 59 |
| `⌿` | — → 4.9–5.9 | 131 → 71 |
| `⊞` | — → 6.7–7.1 | 174 → 77 |
| `⌽` | — → 2.5–3.0 | 112 → 31 |
| list `+` list | 27.6 → 5.6–7.1 | 221 → 61 |
| list `+` int | — → 4.7–5.0 | 176 → 44 |

Not shipped, measured: an `madvise(MADV_HUGEPAGE)` on the heap after each
brk growth in `A` (one line) cuts that page-fault floor to about 1.5 ns and
the `iota` row to 5.1–5.6 ns, for 1–2 MB more peak RSS on the leetcode
inputs (`stock` 31.6 → 32.6 MB). It changes the allocator, not a list word,
so W12-P3 leaves it to the integrator.

W12-A4 shipped `⍒` (sort by key) and `‹grade›` (micro rows `sort`, `ksort`,
`grade`). On 10^6 scrambled ints, best of 3, the 18 ns/element scramble
included: `⍋` 653 ns/element, `‹grade›` 661, `⍒` with an identity key 751,
with `′±` 738. `‹grade›` is `⍋`'s merge sort on indices, so it costs about
the same. `⍒` adds n key calls through `€`, the key block and the gather.
`topk` was rewritten on `⍒`: the key `x - (count<<32)` replaces the packed
key and its unpacking. It went from 100 to 67 bytes and from 0.0885 to
0.0852 s (best of 5, same session), with output equal to Python's on
`gen.py 1 in`.

W13-A (S1 adverbs, `⟦ … ⟧` blocks, bare locals) changes no emitted code.
`f€` compiles to the bytes of `′f€`, `⟦ … ⟧` to those of `:x … ;′x`, and a
bare local to those of `⇐x` (run2.sh's W13-A block compares the binaries), so
run time is unchanged. The compiler does a little more per token: a one-byte
peek and a scan of the adverb record after every call token. That costs
nothing measurable. golf2 compiling the prelude plus all twelve
`bench/leetcode/golf/` files (36,701 bytes) took 19.0 ms before and 19.9 ms
after, and compiling itself 7.2 ms before and 6.8 ms after (mean of 50 runs
each, same session; the run-to-run spread is larger than either difference).
W13-B shipped the bit atoms `♯ ⊣ ⊢ ⊥` (popcount, trailing and leading zero
count, low bit), one inline instruction each (`popcnt` / `tzcnt` / `lzcnt`,
and `mov; neg; and` for `x & -x`). Micro rows `popcnt` and `lowbit`, best of
3: the bare `loop` row is 0.82 ns/iteration and `"♯_` / `"⊣_` / `"⊥_` inside
it 1.12–1.14, so each atom with its dup and drop costs about 0.3 ns. Implicit
output adds 15 bytes to the end-of-program exit (a load, a test and a call
at exit only), and nothing to any loop.
## W13-C

S5 (`± ⊕ ⊖ ² ⊗ ⊘` map over lists) leaves the int path alone: the atom
templates are unchanged, and `100000000{⊕⊖⊖"0≡}_` compiles to the same loop
bytes with the old and the new prelude and runs at 1.40–1.53 ns (old) vs
1.42–1.50 ns (new) per iteration over five interleaved runs (`inc2`).

Cache-resident rows: a 10^5-element list, 1000 passes, best of 3, ns per
element (scrambled = `7919*1000003%` of `⍳`):

| case | ns/el |
|---|---|
| `Ṁ` scrambled | 2.44 |
| `Ṁ` on `⍳` (every element a new max) | 2.77 |
| `Ṃ` scrambled | 2.52 |
| `′⌈⍁` scrambled (what `Ṁ` replaces) | 3.66 |
| `⊕` on a list (S5, one pass) | 2.53 |
| `²` on a list (S5) | 2.53 |
| `′⊕€` | 4.54 |
| list `1+` (M-VEC broadcast) | 3.85 |

`micro.sh` rows (fresh lists, `⍳` included, so subtract `iota`): `lmax`
11.3, `xscan` 16.1 (`scan` 15.6), `findnone` 7.5, `prevocc` 223 and
`counter` 204 per element on 10^6 (one dict probe each, against `dictbump`
120), `dsort` 671 (`ksort` 652: one extra pass of `~` over the keys).
The compiled prelude grew from 74341 to 79691 bytes.
W13-D shipped the LeetCode library (REFERENCE.md "LeetCode library").
Best of 3 on this session's machine, input read from stdin and included
(`ℤ≢` alone is 0.047 s for 10^6 random ints, `⎕≢` 0.017 s for 2·10^6
chars): `ℤ′e‹countif›` 0.057 s (`ℤ′e⌿≢` 0.060 s), `ℤ‹argmax›` 0.049 s,
`ℤ10‹mostcommon›` 0.17 s, `‹union›`/`‹inter›`/`‹diff›` of two 10^6 lists
0.15/0.21/0.15 s (`‹unique›` of one 0.13 s), `‹groupby›` into 100 keys
0.11 s, `‹prefix›` 0.06 s, `3‹chunk›` 0.07 s; 10^6 `‹bisect›` queries on a
sorted 10^6 list about 0.3 s past the 0.58 s sort (~300 ns a query);
`‹find›` (KMP) over 2·10^6 chars 0.05 s; `10000000‹sieve›` 0.14 s; 10^6
`‹powmod›` with a 30-bit modulus 0.26 s (a 62-bit modulus takes the
shift-and-add mulmod, about 10 µs a call); 10^6 `‹isqrt›` 0.07 s. The words
keep their state in `⊡` locals, so none of them takes a spill frame.

### W13-E LeetCode library

Best of 5, wall seconds, input parsing included (`ℤ` alone on the 2M-int
graph file is 0.10 s). Graph: 200,000 vertices and 1,000,000 random edges
(weights 1–99), as `n` then the flat edge list. All answers equal Python's.

| program | s |
|---|---|
| `ℤ"0⊇\\1↓‹adj›≢Ṅ` (build only) | 0.34 |
| `ℤ"0⊇\\1↓‹adj›0‹bfs›∑Ṅ` | 0.39 |
| `ℤ"0⊇\\1↓‹wadj›0‹dijkstra›∑Ṅ` | 1.12 |
| 1M `‹uunion›` over the same edges | 0.19 |
| Islands, `:p49-;⎕10‹split›′p‹gcomps›Ṅ`, the 1000×1000 `gen.py 1` grid | 0.059 (`islands.golfj` today: 0.089) |
| `ℤ‹heapify›≢Ṅ`, 1M ints (`ℤ≢Ṅ` alone: 0.042) | 0.075 |
| `ℤ10‹nlargest›⍕`, 1M ints | 0.077 |
| `ℤ‹nextgreater›∑Ṅ`, 1M ints | 0.076 |
| all 10! `‹perms›` of `10⍳`, each freed | 0.52 |
| the 20C10 `‹combs›` and 2^20 `‹subsets›` of `20⍳`, each freed | 0.37 |

The pack adds 17.9 KB of code to every program: a trivial program (`1Ṅ`)
compiles to 74,351 bytes before W13-E and 92,254 after. It uses no scratch
cells: every word is a `⊡` word with its state in its own frame.
## W13-G: atoms as the function of a higher-order word

W13-G gave `€ ⌿ ⇤ ⍁ ⍀ ⍸ ⊞` a fast path for an atom function (`+ - * ⌈ ⌊`
and `∔ ∸ ⨰ ⩌ ⩍` for the two-operand words, `⊕ ⊖ ± ² ⊗ ⊘` for `€ ⌿`): the
atom runs inline in the word's loop instead of through a call per element.
The micro rows below are `micro.sh`'s cases, the new ones added by W13-G
(`fold scan reduce eachi` were atom cases already: `:f+;` is `′+`'s bytes),
compiled with the base prelude and with W13-G's and run interleaved, best of
5, same session; ns per element, the `iota` row (5.4–6.1) and the result's
page faults included:

| case | program | before | after |
|---|---|---|---|
| fold | `10000000⍳0′+⇤_` | 11.04 | 8.84 |
| reduce | `10000000⍳′+⍁_` | 10.27 | 8.92 |
| scan | `10000000⍳′+⍀_` | 13.47 | 12.06 |
| eachi | `:f+;10000000⍳′f⍸_` | 15.14 | 12.88 |
| mapinc | `10000000⍳′⊕€_` | 13.44 | 11.40 |
| mapsqr | `10000000⍳′²€_` | 13.39 | 13.18 |
| foldmax | `10000000⍳0′⌈⇤_` | 10.60 | 8.17 |
| scanmax | `10000000⍳′⌈⍀_` | 13.62 | 11.88 |
| redmax | `10000000⍳′⌈⍁_` | 10.66 | 8.28 |
| zipadd | `10000000⍳"′+⊞_` | 14.71 | 12.77 |
| zipmin | `10000000⍳"′⩍⊞_` | 21.28 | 12.93 |
| eachimul | `10000000⍳′*⍸_` | 14.57 | 12.78 |
| filtneg | `10000000⍳′±⌿_` | 11.08 | 9.68 |
| map (`:f;`, not an atom) | `:f;10000000⍳′f€_` | 13.96 | 13.82 |

On 10^7 fresh elements the words are memory-bound, so the gain there is
2–3 ns per element. The words' own cost shows on a list that stays in
cache: 10^5 elements, 1000 passes, best of 5, interleaved (ns per element,
the pass's `⌫` included):

| form | before | after |
|---|---|---|
| `′⊕€` | 4.62 | 2.23 |
| `′²€` | 4.42 | 2.20 |
| `′±⌿` | 3.99 | 2.28 |
| `0′+⇤` | 4.05 | 1.92 |
| `0′⌈⇤` | 4.20 | 1.70 |
| `′+⍁` | 3.52 | 1.92 |
| `′+⍀` | 4.82 | 3.07 |
| `′⌊⍀` | 4.90 | 2.96 |
| `′*⍸` | 5.78 | 3.94 |
| `"′+⊞` | 5.87 | 3.11 |
| `"′⩍⊞` | 13.23 | 3.49 |
| `:f;` `′f€` (no fast path) | 4.19 | 4.11 |

The fixed cost per call: `0′+⇤` on a 10-element list, 10^6 calls, 74 → 48
ms; a user word (`:f;10⍳…′f€`, which takes the general path) 113 → 115 ms,
the ~3 ns that recognising f costs (an 8-entry cache, and a cell holding the
last word found not to be an atom). The LeetCode rows above (`lc` = the ten
solutions compiled both ways, interleaved, best of 5, `gen.py 1` inputs,
outputs identical) do not move: stock and trap run `⌈⍀ ⌊⍀ ⌈⍁` over a
million prices, which saves 2–6 ms of 65–90, inside the noise; input parsing
dominates. The prelude grew by about 15 KB of code (a program's image is
74 → 89 KB before its own code; the cap is 192 KB).

Not shipped, measured: the fast loops first used the raw ops (`\radd`, a
branch-free max) with a tag check on every operand and a bail to the general
path; that was slower than the call (5.8 ns per element for `0′+⇤`, against
4.1), because the checks cost more than the call they saved. Inlining the
polymorphic atom itself needs no check at all (its own M-VEC / W12-O1 test
sends a list to `∔` … or `‹_12o1_nan›` exactly as the thunk would) and is
what shipped. Four elements per pass instead of two was 0–10% faster and 6 KB
bigger.

## W13-H: closures as data records, heap not executable

W13-H replaced `∘`/`⊸`'s machine-code thunks with 3-cell data records and
gave `⍎` a heap-floor test (`cmp rax,0x600000; jb`: code is called, a record
runs through its kind word, `call [rax+16]`). Base 07d2afa's toolchain and
W13-H's, both programs compiled from the same sources and run interleaved,
best of 9, same session; ns per iteration (the `⍎` rows are 10^8-iteration
loops, the `€` rows ns per element of 10^7):

| case | program | before | after |
|---|---|---|---|
| loop, no call | `:f;′f→q 100000000{←q_⊖"0≡}_` | 0.95 | 0.95 |
| `⍎` of a word | `:f;′f→q 100000000{←q⍎⊖"0≡}_` | 1.74 | 1.75 |
| `⍎` of a bind | `0′_⊸→q 100000000{←q⍎⊖"0≡}_` | 2.62 | 4.65 |
| `⍎` of a compose | `:f;′f′f∘→q 100000000{←q⍎⊖"0≡}_` | 3.22 | 5.42 |
| `€` of a word | `:f;10000000⍳′f€_` | 13.38 | 13.36 |
| `€` of a bind | `10000000⍳1′+⊸€_` | 14.95 | 17.91 |
| `€` of a compose | `:f;10000000⍳′f′f∘€_` | 14.13 | 16.47 |
| make + free, ∘ then ⊸ | `0→j{′⊗′⊕∘⌫ 5′+⊸⌫ ←j1+"→j1000000<1+}` (per closure) | 50.5 | 22.1 |

So the tag test costs nothing measurable on a code address (`⍎` of a word:
0.79 ns over the bare loop before, 0.80 after; one compare and a taken
branch, predicted). A call through a closure costs about 2 ns more than
through a thunk (bind 1.67 → 3.70 ns over the loop, compose 2.27 → 4.47):
the kind words are GOLF code — a poison test for use after free and the
record read through the data stack — where the thunk was two `mov`/`call`
pairs. Building one is twice as fast (no byte-by-byte code writes) and a
closure is a 40-byte block instead of 72. The prelude got 74 bytes smaller
(a trivial program `1Ṅ`: 125,566 → 125,492 bytes): the 77 `\exec` sites grew
by 14 bytes each and the two thunk assemblers went away. `bench/micro/cases.txt`
has the five rows as `exec bind comp mapbind mapcomp`.

