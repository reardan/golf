# LeetCode benchmark — Golf vs Python, C++ and Jelly

A hundred LeetCode problems: the twenty below, plus eighty more (20 easy,
40 medium, 20 hard) added on 2026-11-15, listed in "The eighty more (P100)".
The first twenty problems, each solved in Golf, Python (idiomatic `py/` and
golfed `pyg/`) and C++. The first ten (3 easy, 4 medium, 3 hard) also have
Jelly. Every program reads stdin (Jelly takes arguments, the usual Jelly way)
and prints the answer. The first ten are the baseline
[`../../PLAN_W12.md`](../../PLAN_W12.md) measures itself against. W13-F
added the second ten so that the language is not tuned to only ten programs:
each one leans on a different word of the W13 library.

```sh
./build.sh                  # golfc every golf/*.golfj, g++ -O2 every cpp/*.cpp, into bin/
python3 gen.py 1 in         # the large inputs (~59 MB); `gen.py 0.001 small` for tiny ones
./bench.sh in               # golf / py / cpp: outputs must agree, best-of-3 wall seconds
./bytes.sh                  # sizes: golf code-page bytes, pyg, py, cpp, jelly; totals
JELLY='jelly eu' python3 jbench.py stock=20000 queens=9   # all four at sizes Jelly can finish
python3 rss.py in/stock.txt bin/stock                     # peak RSS of one run, KB
../../tools/golfc -j rss.golfj bin/rss && bin/rss in/stock.txt bin/stock   # the same in Golf (W14-B)
```

`rss.py` reads `RUSAGE_CHILDREN`, which also counts the forked Python before
its `exec` (about 13 MB); `rss.golfj` reports the child's own peak, so the two
agree only for a child bigger than that.

| Problem | Level | Large input |
|---|---|---|
| 1 Two Sum | Easy | 200k distinct ints |
| 20 Valid Parentheses | Easy | 2M chars |
| 121 Best Time to Buy and Sell Stock (`stock`) | Easy | 1M prices |
| 3 Longest Substring Without Repeating (`longsub`) | Medium | 2M letters |
| 238 Product of Array Except Self (`prodself`) | Medium | 1M values ±1 |
| 347 Top K Frequent Elements (`topk`) | Medium | 1M ints, k = 10 |
| 200 Number of Islands | Medium | 1000 × 1000 grid |
| 42 Trapping Rain Water (`trap`) | Hard | 1M heights |
| 239 Sliding Window Maximum (`slidemax`) | Hard | 1M ints, k = 1000 |
| 52 N-Queens II (`queens`) | Hard | n = 12 |
| 35 Search Insert Position (`search`) | Easy | 1M sorted ints |
| 875 Koko Eating Bananas (`koko`) | Medium | 100k piles up to 10^9 |
| 994 Rotting Oranges (`oranges`) | Medium | 1000 × 1000 grid |
| 207 Course Schedule (`course`) | Medium | 200k courses, 400k prerequisites |
| 743 Network Delay Time (`delay`) | Medium | 100k nodes, 500k edges |
| 684 Redundant Connection (`redundant`) | Medium | 500k nodes |
| 322 Coin Change (`coins`) | Medium | amount 100k, 20 coins |
| 1143 Longest Common Subsequence (`lcs`) | Medium | two 2000-letter strings |
| 739 Daily Temperatures (`temps`) | Medium | 1M temperatures |
| 338 Counting Bits (`bits`) | Easy | n = 1M |

The input formats are `py/`'s: whitespace-separated integers, the scalar
first (`target`, `h`, `k`, `n`, `amount`, `n k` for `delay`), edges as a
flat list (`a b` pairs for `course`, meaning b before a; 1-based `u v w`
triples for `delay` and `u v` pairs for `redundant`); grids and strings one
row or string per line.

Baseline, 2026-11-08 (main after PR #16), wall seconds on the large inputs:

| Problem | Golf bytes | Golf s (of which input) | Python s | C++ s |
|---|---|---|---|---|
| twosum | 92 | 0.293 (0.188) | 0.096 | 0.063 |
| parens | 131 | 0.147 (0.080) | 0.155 | 0.019 |
| stock | 26 | 0.566 (0.524) | 0.235 | 0.032 |
| longsub | 62 | 0.142 (0.087) | 0.349 | 0.009 |
| prodself | 32 | 0.411 (0.316) | 1.175 | 0.080 |
| topk | 127 | 0.564 (0.245) | 0.087 | 0.032 |
| islands | 158 | 0.089 (0.028) | 0.559 | 0.019 |
| trap | 33 | 0.620 (0.469) | 0.292 | 0.059 |
| slidemax | 127 | 0.633 (0.539) | 1.406 | 0.097 |
| queens | 110 | 0.022 (—) | 0.169 | 0.012 |
| **total bytes** | **898** | | golfed Python 1,300 · Python 2,571 · C++ 4,613 · Jelly 144 | |

W13 final, 2026-11-08 (W13-F), the better of two `./bench.sh in` runs:

| Problem | Golf bytes (W12 → W13) | Golf s | Python s | C++ s |
|---|---|---|---|---|
| twosum | 54 → 32 | 0.091 | 0.099 | 0.067 |
| parens | 41 → 22 | 0.081 | 0.146 | 0.018 |
| stock | 10 → 6 | 0.073 | 0.196 | 0.029 |
| longsub | 42 → 9 | 0.174 | 0.332 | 0.008 |
| prodself | 27 → 12 | 0.130 | 0.974 | 0.071 |
| topk | 31 → 17 | 0.071 | 0.087 | 0.027 |
| islands | 101 → 7 | 0.049 | 0.446 | 0.016 |
| trap | 16 → 11 | 0.090 | 0.259 | 0.048 |
| slidemax | 11 → 4 | 0.142 | 1.145 | 0.082 |
| queens | 78 → 57 | 0.018 | 0.176 | 0.011 |
| **first ten** | **411 → 177** | | golfed Python 1,300 · Python 2,571 · C++ 4,613 · Jelly 144 | |
| search | 4 | 0.077 | 0.138 | 0.076 |
| koko | 25 | 0.045 | 0.215 | 0.019 |
| oranges | 121 | 0.395 | 0.741 | 0.020 |
| course | 15 | 0.124 | 0.452 | 0.085 |
| delay | 28 | 0.265 | 1.057 | 0.142 |
| redundant | 33 | 0.199 | 0.524 | 0.054 |
| coins | 54 | 0.058 | 0.169 | 0.007 |
| lcs | 33 | 0.178 | 0.492 | 0.008 |
| temps | 7 | 0.124 | 0.992 | 0.084 |
| bits | 6 | 0.047 | 0.824 | 0.056 |
| **all twenty** | **503** | | golfed Python 2,997 · Python 5,626 · C++ 10,098 | |

Every problem beats Python. The machine is a shared container, so take
±15% as noise: twosum ran in 0.058–0.091 s across runs, against Python's
0.080–0.099.

W15 final, 2026-11-12, the better of two `./bench.sh in` runs (the same
container measured the W13 programs at 2.95 s in total that day, in one run):

| Problem | Golf bytes (W13 → W15) | Jelly bytes | Golf s | Python s | C++ s |
|---|---|---|---|---|---|
| twosum | 32 → 4 | 11 | 0.055 | 0.098 | 0.062 |
| parens | 22 → 10 | 25 | 0.078 | 0.162 | 0.018 |
| stock | 6 → 4 | 4 | 0.075 | 0.199 | 0.028 |
| longsub | 9 → 9 | 6 | 0.136 | 0.381 | 0.008 |
| prodself | 12 → 7 | 8 | 0.108 | 1.106 | 0.078 |
| topk | 17 → 6 | 9 | 0.094 | 0.101 | 0.029 |
| islands | 7 → 7 | 50 | 0.059 | 0.492 | 0.018 |
| trap | 11 → 9 | 11 | 0.099 | 0.277 | 0.058 |
| slidemax | 4 → 3 | 3 | 0.140 | 1.183 | 0.094 |
| queens | 57 → 56 | 17 | 0.021 | 0.197 | 0.012 |
| **first ten** | **177 → 115** | **144** | | golfed Python 1,300 · Python 2,571 · C++ 4,613 | |
| search | 4 → 3 | | 0.089 | 0.164 | 0.070 |
| koko | 25 → 21 | | 0.086 | 0.254 | 0.020 |
| oranges | 121 → 12 | | 0.079 | 0.892 | 0.021 |
| course | 15 → 10 | | 0.164 | 0.523 | 0.116 |
| delay | 28 → 16 | | 0.362 | 1.397 | 0.191 |
| redundant | 33 → 16 | | 0.169 | 0.602 | 0.061 |
| coins | 54 → 11 | | 0.034 | 0.162 | 0.007 |
| lcs | 33 → 24 | | 0.169 | 0.540 | 0.008 |
| temps | 7 → 6 | | 0.133 | 1.095 | 0.094 |
| bits | 6 → 5 | | 0.057 | 0.849 | 0.046 |
| **all twenty** | **503 → 239** | | **2.21** | **10.67** | **1.04** |

The ten that Jelly has are now 29 bytes shorter in Golf than in Jelly, and
Golf's are the linear or n log n algorithms where Jelly's are mostly brute
force (its Two Sum is O(n²), its N-Queens O(n!)). Golf is shorter on seven of
the ten, level on Stock, and longer on `longsub` (9 to 6) and `queens` (56 to
17): Jelly's N-Queens tries every permutation in 17 bytes, and Golf's bitmask
recursion is the one solution here that still spells out its own loop.
Every problem still beats Python, `topk` only just, and `twosum` beats the
C++ `unordered_map`.

W16 final, 2026-11-15, one `./bench.sh in` run on the same shared container:

| Problem | Golf bytes (W15 → W16) | Golf s | Python s | C++ s |
|---|---|---|---|---|
| twosum | 4 → 4 | 0.053 | 0.104 | 0.056 |
| parens | 10 → 3 | 0.066 | 0.202 | 0.023 |
| stock | 4 → 4 | 0.078 | 0.255 | 0.037 |
| longsub | 9 → 8 | 0.142 | 0.449 | 0.008 |
| prodself | 7 → 2 | 0.117 | 1.515 | 0.090 |
| topk | 6 → 6 | 0.116 | 0.130 | 0.037 |
| islands | 7 → 7 | 0.070 | 0.608 | 0.020 |
| trap | 9 → 7 | 0.113 | 0.314 | 0.059 |
| slidemax | 3 → 3 | 0.199 | 1.633 | 0.105 |
| queens | 56 → 14 | 1.308 | 0.221 | 0.013 |
| **first ten** | **115 → 58** | | | |
| search | 3 → 3 | 0.094 | 0.170 | 0.080 |
| koko | 21 → 13 | 0.061 | 0.286 | 0.024 |
| oranges | 12 → 12 | 0.085 | 1.040 | 0.025 |
| course | 10 → 9 | 0.154 | 0.572 | 0.089 |
| delay | 16 → 16 | 0.337 | 1.270 | 0.181 |
| redundant | 16 → 11 | 0.183 | 0.547 | 0.069 |
| coins | 11 → 11 | 0.040 | 0.211 | 0.007 |
| lcs | 24 → 19 | 0.233 | 0.826 | 0.011 |
| temps | 6 → 6 | 0.162 | 1.467 | 0.113 |
| bits | 5 → 3 | 0.060 | 1.241 | 0.055 |
| **all twenty** | **239 → 161** | **3.67** | **13.06** | **1.10** |

Golf is now shorter than every rival on the first ten (58 against Nibbles' 92)
and on all twenty (161 against 220). The price is `queens`: it is now the
backtracking permutation search `⍥` with an all-distinct test, as the rivals
write it, 14 bytes instead of 56 but 1.3 s instead of 0.02 s on n = 12, the
one problem where Golf is slower than Python. It is still a pruned search
(a prefix that fails is never extended), not O(n!) over all permutations.

### Byte ceilings

The current size of each Golf solution, as `./bytes.sh` counts it. The gate
(`test/run2.sh`, block W12-O4) compiles every solution, checks its answer
against `py/` on `gen.py 0.001` inputs (and the small edge cases `gen.py`
writes as `name2.txt`, `name3.txt` …), and fails if a solution is larger
than its number here. A solution may only get shorter: when one shrinks,
lower its number.

| problem | bytes |
|---|---|
| twosum | 4 |
| parens | 3 |
| stock | 4 |
| longsub | 8 |
| prodself | 2 |
| topk | 6 |
| islands | 7 |
| trap | 7 |
| slidemax | 3 |
| queens | 14 |
| search | 3 |
| koko | 13 |
| oranges | 12 |
| course | 9 |
| delay | 16 |
| redundant | 11 |
| coins | 11 |
| lcs | 19 |
| temps | 6 |
| bits | 3 |
| palnum | 4 |
| roman | 32 |
| lcp | 14 |
| dedup | 3 |
| lastword | 4 |
| plusone | 19 |
| sqrtx | 8 |
| stairs | 11 |
| validpal | 18 |
| single | 2 |
| majority | 3 |
| dupe | 3 |
| anagram | 6 |
| missing | 5 |
| zeroes | 5 |
| firstuniq | 5 |
| longpal | 9 |
| maxones | 7 |
| binsearch | 4 |
| sqsorted | 2 |
| longpalsub | 70 |
| water | 13 |
| threesum | 41 |
| rotsearch | 4 |
| firstlast | 15 |
| combsum | 16 |
| jumpii | 21 |
| rotate | 12 |
| maxsub | 8 |
| spiral | 18 |
| jump | 9 |
| merge | 21 |
| paths | 15 |
| minpath | 23 |
| edit | 32 |
| decode | 33 |
| bsts | 14 |
| consec | 13 |
| gas | 17 |
| wordbreak | 43 |
| rpn | 41 |
| maxprod | 12 |
| largest | 29 |
| rob | 11 |
| minsubarr | 21 |
| kth | 7 |
| square | 28 |
| squares | 20 |
| lis | 18 |
| cooldown | 28 |
| partition | 14 |
| charrep | 29 |
| nonoverlap | 23 |
| arrows | 23 |
| targetsum | 24 |
| change | 23 |
| provinces | 17 |
| subarrk | 22 |
| palsubs | 44 |
| maxarea | 49 |
| median | 26 |
| regex | 70 |
| mergek | 1 |
| validparens | 22 |
| firstmiss | 11 |
| wildcard | 35 |
| minwindow | 52 |
| histogram | 17 |
| maxrect | 32 |
| distinct | 25 |
| stockiii | 14 |
| ladder | 80 |
| candy | 19 |
| stockiv | 16 |
| calc | 62 |
| balloons | 58 |
| smaller | 40 |
| envelopes | 28 |
| splitarr | 36 |
| revpairs | 46 |

Total 1936: the first twenty 161, the eighty after them 1,775 (P100 1,782, less 7 from W17's gather in `minwindow` and `wordbreak`).
The first twenty: the first ten 58 (115 before W16's rewrite, 177 before W15's,
411 before W13-F's, 655 before W12-6's, 898 at the baseline above), the
second ten 103 (124 before W16, 326 before W15).

### Notes

W16 (REFERENCE "W16") rewrote ten of them; the notes below give the W16
form where it changed. W15 rewrote all twenty with implicit input (no program starts with `ℤ` any
more: a word that finds the stack empty takes the input, and takes it again
when it needs a second copy) and the structure adverbs (REFERENCE "Structure
adverbs (W15)"). Each keeps its algorithm's time complexity. Stock, Trap and
Sliding Window are explained in REFERENCE.md §4, "LeetCode in Golf". The
others:

- **twosum** `⍘&-⋈`. `⍘` splits the input into the numbers and the target
  on top, `&-` makes `target - x` for every number (`&` takes the numbers
  again), and `⋈` is the hash join: the pair `j i` for which `target - x[i]`
  is an earlier `x[j]`. One pass, one table. The problem promises exactly one
  solution; with more, every `i` that has a partner prints its pair.
- **parens** `ʘ(ṭ`. `‹balanced›` (`ʘ(`) gives `0` when `()[]{}` balance,
  `ṭ` turns the flag into the text `true`/`false`, and implicit output prints
  a text list as text (W16's text mark), so no `⊐`. Before W16 it was the
  stack-cancel adverb `⍙` over a code map, `⊖⊘⟦-⊕⟧⍙≢ṭ⊐` (10 bytes).
- **longsub** `ℓṔ⌈⍀ℑ\\-Ṁ`. `Ṕ` gives each letter's previous position,
  `⌈⍀` the running maximum of those, the start of the window ending at `i`
  less one, and `ℑ\\-` turns that into the window lengths. `ℓ` reads the line
  raw (W16): the string may begin with a digit, which implicit input would
  read as numbers. Since W15 `Ṕ` uses a table instead of a dict when the
  values span a small range.
- **prodself** `*⍜`: `⍜` folds `*` over every element but `i`, as an
  exclusive prefix scan times an exclusive suffix scan. No division, so zeros
  are fine.
- **topk** `⍘\\⍋\\ʘk`: sort the numbers, then `‹mostcommon›`, whose ties
  fall in first-appearance order, which after the sort is value order, as
  Python's `(-count, value)` key has them. The radix sort is one pass here,
  and `‹mostcommon›` counts small-range values in a table.
- **islands** `⎕ʘW′⊣ʘ7`: `‹words›` splits the grid into rows, and
  `‹gcomps›` counts the components of the cells its predicate accepts.
  The predicate is the trailing-zero-count atom `⊣`, which is `0` for `1`
  (49, odd) and not for `0` (48) or the newline (10). (It reads with `⎕`:
  the grid starts with a digit.)
- **queens** `∑⟦"+⍸Ḍ\\-⍸Ḍ|⟧⍥≢`. `∑` of the one-number input is `n`; `⍥`
  enumerates the permutations of `0 … n-1` column by column and drops every
  prefix its predicate rejects, so only the boards that are safe so far are
  extended. The predicate takes a prefix `p`: `p+i` all distinct (`"+⍸Ḍ`)
  and `p-i` all distinct (`\\-⍸Ḍ`), both zero for true, `|` joins them. `≢`
  counts the full boards. Before W16 it was a 56-byte bitmask recursion
  (0.02 s against 1.3 s now).

The second ten:

- **search** `⍘ʘb` is `‹bisect›`; **temps** `ʘnℑ-0⌈` is `‹nextgreater›`
  less the index, clamped at `0`; **bits** maps the popcount atom
  over `0 … n`, `ʀ` (W16) being the inclusive range: `∑ʀ♯`.
- **koko** `1②Ṁ⟦②\\⌹∑①≻⟧ʘh` binary-searches the speed with `‹bsearch›`
  (`ʘh`) over `[1, max)`, `②` being the piles (the input's second line) and
  `①` the hours. The predicate is `ceil(p/k)` summed, `⌹` the W16 ceiling
  division broadcasting the scalar `k`, compared with `≻` (which maps since
  W16): "the hours exceed `h`".
- **oranges** `⎕ʘW50 48ʘ@⊔⍁`: `‹gdist›` (`ʘ@`) is the multi-source grid BFS,
  from every `2` (code 50), with `0` (48) as the wall. `⊔⍁` reduces the
  distances with the raw, unsigned maximum: the answer is the largest
  distance, and a fresh orange that nothing reaches is `-1`, which as an
  unsigned number beats every distance, so the answer is then `-1`.
- **course** `⍘\\ʘ/ʘo\\_ṭ` (the text mark prints `ṭ`'s result, W16): `‹dadj›` (`ʘ/`) builds the graph and
  `‹toposort›` fails exactly when there is a cycle.
- **delay** `⍘⊕\\⍘→kʘ|←kʘw1↓⊔⍁`: `‹dwadj›` (`ʘ|`) and `‹dijkstra›` (`ʘw`)
  from `k`, the 1-based list less its vertex 0, then `⊔⍁` again: the
  largest distance, or `-1` if any vertex is unreached.
- **redundant** `⍘⊕ʘ=\\2ʘ%ʘu⍭`: a union-find (`ʘ=`), the edges as
  pairs (`2ʘ%`), and `⍭` (W16) stops at the first edge for which
  `‹uunion›` answers non-zero: its ends were already joined.
- **coins** `⍘⊕0⟦&+⟧ʘ>ʘ$`: Coin Change is a shortest path. The vertices are
  the amounts `0 … amount`, `&+` adds every coin to an amount, and `‹bfsf›`
  (`ʘ>`) is BFS over that function from `0`; `ʘ$` takes the last distance,
  `-1` when the amount cannot be made.
- **lcs** `②①0*⟦&0⌈⍃\\①≡-⌈⌈⍀⟧⇤Ṁ` folds one row per letter of the
  second string (`②`, the input's second line as a code list). With `P` the
  previous row (non-decreasing), the new one is `⌈⍀ max(P, (0⌈⍃ P) + E)`,
  where `0⌈⍃` shifts `P` right by one and `E` is 1 where the first string
  (`①`) has the letter (`≡` broadcasts the letter since W16; true is `-1`,
  hence `-`). O(mn), with vector ops in place of a call per cell.

`golf/stock_stream.golfj` (W12-A8) is Stock as a stream, `‹sints›′p‹smap›0′⌈‹sfold›`
with the running minimum threaded under the pipeline and dropped by a final `_`
(W13-B: implicit output would print it): 41 bytes, about 0.09 s
and 13 MB peak on the `stock` input, against `stock.golfj`'s 0.07 s and 32 MB
(both measured after W12-P1), and constant memory however long the input. It
is not one of the twenty that `bench.sh` runs.

`golf/stream_ints_proto.golfj` is the 2-line `‹getc›` integer reader that
reads the `stock` input in 0.07 s and 13 MB, against `‹ints›`'s 0.52 s and
179 MB: the evidence for PLAN_W12's P1. The full write-up, with the Jelly
timings and per-problem notes, is the doc linked from PLAN_W12.md.

## Golf against Vyxal, 05AB1E and Nibbles (2026-11-13)

The twenty problems are also solved in three golfing languages that often beat
Jelly: `vyxal/*.vy` (Vyxal 2.21, its one-byte code page), `05ab1e/*.abe`
(05AB1E, Elixir version, its code page) and `nibbles/*.nbl` (Nibbles,
literate form; scored as its packed half-byte form, rounded up to bytes).
They take the problem's LeetCode arguments rather than stdin (`rivals.py`'s
`conv` gives the argument list of each), as the Jelly ones do.

| | first ten | all twenty |
|---|---|---|
| Golf (W16) | 58 | 161 |
| Nibbles | 92 | 220 |
| Vyxal | 99 | 297 |
| Golf (W15) | 115 | 239 |
| 05AB1E | 136 | 364 |
| Jelly | 144 | — |

Per problem (Golf W15 / Vyxal / 05AB1E / Nibbles): twosum 4/12/14/8, parens
10/2/8/13, stock 4/5/6/5, longsub 9/8/9/9, prodself 7/6/8/3, topk 6/11/10/8,
islands 7/26/41/20, trap 9/12/16/8, slidemax 3/3/5/6, queens 56/14/19/12,
search 3/2/2/3, koko 21/16/19/14, oranges 12/38/54/21, course 10/15/15/10,
delay 16/54/57/31, redundant 16/15/15/9, coins 11/21/26/12, lcs 24/26/24/16,
temps 6/8/11/7, bits 5/3/5/5. The W16 sizes are in the table above.

These rival solutions are a first pass, not expert golf, and most are brute
force (O(n²) up to O(n!)): on `gen.py 0.001` inputs Vyxal and 05AB1E time out
(60 s) on islands and oranges, and longsub and koko time out in one of them;
Nibbles, which compiles through GHC, finishes all but islands. None can run the
full-size inputs. The write-up, with timings and what Golf could borrow, is
https://claude.ai/artifact/5rYuhM4qgfDYZjhZt6JkC7.

```sh
python3 gen.py 0.0001 small                     # tiny inputs + every edge case
RIVALS_EXT=~/rivals python3 rivals.py nibbles   # or vyxal, 05ab1e, golf; --set DIR, TMO=seconds
```

`rivals.py` checks each solution against `py/` and prints its bytes and time.
It needs `vyxal` on PATH (`pip install vyxal`), the 05AB1E escript at
`$RIVALS_EXT/05AB1E/osabie` and the Nibbles binary at `$RIVALS_EXT/nibbles/nibbles`
(GHC plus the `dlist split murmur-hash memoize` packages). Building 05AB1E
without hex.pm: drop the `httpoison`, `excoveralls` and `mock` deps from
`mix.exs` (only `.w`, read a URL, uses HTTPoison), copy `melpon/memoize`'s `lib/`
into `lib/`, start `Memoize.Application` at the top of `main`, then
`MIX_ENV=prod mix escript.build`. Nibbles needs the argument types when it
compiles, so `rivals.py` passes `small/<problem>.txt`'s arguments to
`nibbles -c` and `-hs`. 05AB1E evaluates an input line that starts with `[` as
a list, so it cannot take a bracket string that starts with `[`.

## The eighty more (P100, 2026-11-15)

Eighty more problems, so that the language is measured on more than the
twenty it was tuned on: 20 easy, 40 medium and 20 hard. Each has a Python
reference (`py/`), a generator (`gen/<name>.py`, which `gen.py` runs after the
twenty, each with its own `random.Random(<name>)` seed, writing the full input
and the edge cases `<name>2.txt` …), the Golf solution (`golf/`), and a note
(`notes/<name>.md`: input format, how the solution works, and the Golf gaps it
hit). They have no C++, golfed Python or rival-language solutions. Every Golf
solution gives Python's answer on the gate's tiny inputs and edge cases and on
the full input, and (checked once when written, not in the gate) on 150 to 300
random small inputs each.

```sh
./check.sh NAME full        # compile golf/NAME, compare with py/NAME on its small and full inputs, time both
python3 gen1.py NAME 1 in   # just NAME's inputs
./bench.sh in NAME …        # the bench for some problems; bytes.sh covers all hundred
```

One `./check.sh NAME full` run each (single runs on a shared container, so
±20%): bytes, then wall seconds on the full input.

| Problem | Level | Golf bytes | Golf s | Python s | |
|---|---|---|---|---|---|
| 9 Palindrome Number (`palnum`) | Easy | 4 | 0.004 | 0.014 | [notes](notes/palnum.md) |
| 13 Roman to Integer (`roman`) | Easy | 32 | 0.329 | 0.129 | [notes](notes/roman.md) |
| 14 Longest Common Prefix (`lcp`) | Easy | 14 | 0.650 | 1.134 | [notes](notes/lcp.md) |
| 26 Remove Duplicates from Sorted Array (`dedup`) | Easy | 3 | 0.273 | 0.238 | [notes](notes/dedup.md) |
| 58 Length of Last Word (`lastword`) | Easy | 4 | 0.452 | 0.121 | [notes](notes/lastword.md) |
| 66 Plus One (`plusone`) | Easy | 19 | 0.244 | 0.199 | [notes](notes/plusone.md) |
| 69 Sqrt(x) (`sqrtx`) | Easy | 8 | 0.004 | 0.020 | [notes](notes/sqrtx.md) |
| 70 Climbing Stairs (`stairs`) | Easy | 11 | 0.005 | 0.016 | [notes](notes/stairs.md) |
| 125 Valid Palindrome (`validpal`) | Easy | 18 | 0.276 | 0.453 | [notes](notes/validpal.md) |
| 136 Single Number (`single`) | Easy | 2 | 0.096 | 0.263 | [notes](notes/single.md) |
| 169 Majority Element (`majority`) | Easy | 3 | 0.273 | 0.227 | [notes](notes/majority.md) |
| 217 Contains Duplicate (`dupe`) | Easy | 3 | 0.317 | 0.259 | [notes](notes/dupe.md) |
| 242 Valid Anagram (`anagram`) | Easy | 6 | 0.350 | 0.136 | [notes](notes/anagram.md) |
| 268 Missing Number (`missing`) | Easy | 5 | 0.096 | 0.168 | [notes](notes/missing.md) |
| 283 Move Zeroes (`zeroes`) | Easy | 5 | 0.178 | 1.139 | [notes](notes/zeroes.md) |
| 387 First Unique Character in a String (`firstuniq`) | Easy | 5 | 0.205 | 0.202 | [notes](notes/firstuniq.md) |
| 409 Longest Palindrome (`longpal`) | Easy | 9 | 0.238 | 0.142 | [notes](notes/longpal.md) |
| 485 Max Consecutive Ones (`maxones`) | Easy | 7 | 0.126 | 0.380 | [notes](notes/maxones.md) |
| 704 Binary Search (`binsearch`) | Easy | 4 | 0.107 | 0.233 | [notes](notes/binsearch.md) |
| 977 Squares of a Sorted Array (`sqsorted`) | Easy | 2 | 0.406 | 1.502 | [notes](notes/sqsorted.md) |
| 5 Longest Palindromic Substring (`longpalsub`) | Medium | 70 | 0.281 | 0.702 | [notes](notes/longpalsub.md) |
| 11 Container With Most Water (`water`) | Medium | 13 | 0.380 | 0.359 | [notes](notes/water.md) |
| 15 3Sum (`threesum`) | Medium | 41 | 0.607 | 0.620 | [notes](notes/threesum.md) |
| 33 Search in Rotated Sorted Array (`rotsearch`) | Medium | 4 | 0.122 | 0.176 | [notes](notes/rotsearch.md) |
| 34 Find First and Last Position of Element in Sorted Array (`firstlast`) | Medium | 15 | 0.093 | 0.150 | [notes](notes/firstlast.md) |
| 39 Combination Sum (`combsum`) | Medium | 16 | 0.140 | 0.146 | [notes](notes/combsum.md) |
| 45 Jump Game II (`jumpii`) | Medium | 21 | 0.079 | 0.211 | [notes](notes/jumpii.md) |
| 48 Rotate Image (`rotate`) | Medium | 12 | 0.258 | 0.606 | [notes](notes/rotate.md) |
| 53 Maximum Subarray (`maxsub`) | Medium | 8 | 0.102 | 0.294 | [notes](notes/maxsub.md) |
| 54 Spiral Matrix (`spiral`) | Medium | 18 | 1.151 | 0.131 | [notes](notes/spiral.md) |
| 55 Jump Game (`jump`) | Medium | 9 | 0.147 | 0.236 | [notes](notes/jump.md) |
| 56 Merge Intervals (`merge`) | Medium | 21 | 0.139 | 0.323 | [notes](notes/merge.md) |
| 62 Unique Paths (`paths`) | Medium | 15 | 0.039 | 0.096 | [notes](notes/paths.md) |
| 64 Minimum Path Sum (`minpath`) | Medium | 23 | 0.150 | 0.279 | [notes](notes/minpath.md) |
| 72 Edit Distance (`edit`) | Medium | 32 | 0.449 | 0.711 | [notes](notes/edit.md) |
| 91 Decode Ways (`decode`) | Medium | 33 | 0.066 | 0.403 | [notes](notes/decode.md) |
| 96 Unique Binary Search Trees (`bsts`) | Medium | 14 | 0.003 | 0.013 | [notes](notes/bsts.md) |
| 128 Longest Consecutive Sequence (`consec`) | Medium | 13 | 0.222 | 0.244 | [notes](notes/consec.md) |
| 134 Gas Station (`gas`) | Medium | 17 | 0.193 | 0.445 | [notes](notes/gas.md) |
| 139 Word Break (`wordbreak`) | Medium | 46 | 0.712 | 0.182 | [notes](notes/wordbreak.md) |
| 150 Evaluate Reverse Polish Notation (`rpn`) | Medium | 41 | 0.295 | 0.247 | [notes](notes/rpn.md) |
| 152 Maximum Product Subarray (`maxprod`) | Medium | 12 | 0.090 | 0.381 | [notes](notes/maxprod.md) |
| 179 Largest Number (`largest`) | Medium | 29 | 0.492 | 0.316 | [notes](notes/largest.md) |
| 198 House Robber (`rob`) | Medium | 11 | 0.060 | 0.202 | [notes](notes/rob.md) |
| 209 Minimum Size Subarray Sum (`minsubarr`) | Medium | 21 | 0.340 | 0.447 | [notes](notes/minsubarr.md) |
| 215 Kth Largest Element in an Array (`kth`) | Medium | 7 | 0.130 | 0.404 | [notes](notes/kth.md) |
| 221 Maximal Square (`square`) | Medium | 28 | 0.165 | 0.173 | [notes](notes/square.md) |
| 279 Perfect Squares (`squares`) | Medium | 20 | 0.067 | 0.254 | [notes](notes/squares.md) |
| 300 Longest Increasing Subsequence (`lis`) | Medium | 18 | 0.345 | 0.447 | [notes](notes/lis.md) |
| 309 Best Time to Buy and Sell Stock with Cooldown (`cooldown`) | Medium | 28 | 0.110 | 0.356 | [notes](notes/cooldown.md) |
| 416 Partition Equal Subset Sum (`partition`) | Medium | 14 | 0.063 | 0.099 | [notes](notes/partition.md) |
| 424 Longest Repeating Character Replacement (`charrep`) | Medium | 29 | 0.709 | 0.097 | [notes](notes/charrep.md) |
| 435 Non-overlapping Intervals (`nonoverlap`) | Medium | 23 | 0.178 | 0.274 | [notes](notes/nonoverlap.md) |
| 452 Minimum Number of Arrows to Burst Balloons (`arrows`) | Medium | 23 | 0.144 | 0.451 | [notes](notes/arrows.md) |
| 494 Target Sum (`targetsum`) | Medium | 24 | 0.103 | 0.234 | [notes](notes/targetsum.md) |
| 518 Coin Change II (`change`) | Medium | 23 | 0.047 | 0.114 | [notes](notes/change.md) |
| 547 Number of Provinces (`provinces`) | Medium | 17 | 0.220 | 0.183 | [notes](notes/provinces.md) |
| 560 Subarray Sum Equals K (`subarrk`) | Medium | 22 | 0.239 | 0.328 | [notes](notes/subarrk.md) |
| 647 Palindromic Substrings (`palsubs`) | Medium | 44 | 0.403 | 0.784 | [notes](notes/palsubs.md) |
| 695 Max Area of Island (`maxarea`) | Medium | 49 | 0.230 | 0.609 | [notes](notes/maxarea.md) |
| 4 Median of Two Sorted Arrays (`median`) | Hard | 26 | 0.231 | 0.126 | [notes](notes/median.md) |
| 10 Regular Expression Matching (`regex`) | Hard | 70 | 0.755 | 1.702 | [notes](notes/regex.md) |
| 23 Merge k Sorted Lists (`mergek`) | Hard | 1 | 0.106 | 0.289 | [notes](notes/mergek.md) |
| 32 Longest Valid Parentheses (`validparens`) | Hard | 22 | 0.135 | 0.264 | [notes](notes/validparens.md) |
| 41 First Missing Positive (`firstmiss`) | Hard | 11 | 0.770 | 1.091 | [notes](notes/firstmiss.md) |
| 44 Wildcard Matching (`wildcard`) | Hard | 35 | 0.138 | 0.145 | [notes](notes/wildcard.md) |
| 76 Minimum Window Substring (`minwindow`) | Hard | 56 | 0.627 | 0.208 | [notes](notes/minwindow.md) |
| 84 Largest Rectangle in Histogram (`histogram`) | Hard | 17 | 0.117 | 0.253 | [notes](notes/histogram.md) |
| 85 Maximal Rectangle (`maxrect`) | Hard | 32 | 0.244 | 0.564 | [notes](notes/maxrect.md) |
| 115 Distinct Subsequences (`distinct`) | Hard | 25 | 0.686 | 0.712 | [notes](notes/distinct.md) |
| 123 Best Time to Buy and Sell Stock III (`stockiii`) | Hard | 14 | 0.158 | 0.401 | [notes](notes/stockiii.md) |
| 127 Word Ladder (`ladder`) | Hard | 80 | 1.723 | 0.652 | [notes](notes/ladder.md) |
| 135 Candy (`candy`) | Hard | 19 | 0.090 | 0.218 | [notes](notes/candy.md) |
| 188 Best Time to Buy and Sell Stock IV (`stockiv`) | Hard | 16 | 0.037 | 0.157 | [notes](notes/stockiv.md) |
| 224 Basic Calculator (`calc`) | Hard | 62 | 0.132 | 0.605 | [notes](notes/calc.md) |
| 312 Burst Balloons (`balloons`) | Hard | 58 | 0.428 | 0.255 | [notes](notes/balloons.md) |
| 315 Count of Smaller Numbers After Self (`smaller`) | Hard | 40 | 0.190 | 0.252 | [notes](notes/smaller.md) |
| 354 Russian Doll Envelopes (`envelopes`) | Hard | 28 | 0.367 | 0.597 | [notes](notes/envelopes.md) |
| 410 Split Array Largest Sum (`splitarr`) | Hard | 36 | 0.263 | 0.577 | [notes](notes/splitarr.md) |
| 493 Reverse Pairs (`revpairs`) | Hard | 46 | 1.142 | 0.600 | [notes](notes/revpairs.md) |
| **eighty** | | **1782** | **22.73** | **29.37** | |

Golf is shorter than idiomatic Python on every one (1,782 bytes against
Python's 21,458; never more than a third of it), but it is slower than Python on 21
of the 80, in total 22.7 s against Python's 29.4 s. The slow ones are where a
solution builds a list per element or per step that is never freed (`spiral`
1.2 s against 0.13 and 646 MB, `charrep`, `balloons`), where a word costs more
than it looks (`‹slice›`, `‹words›` in `lastword`), or where the algorithm had
to be spelled out (`ladder`, `revpairs`, `wordbreak`, `minwindow`).

Where the agents that wrote them chose a simpler algorithm than LeetCode's,
the note says so: `rotsearch` and `binsearch` scan linearly (reading the
input is O(n) anyway), `median` and `mergek` sort everything (the radix sort
is linear), and `water` uses the sorted order rather than two pointers.

### Golf gaps the eighty found

Most costly first, counted over the eighty notes:

1. **Two bugs.** *Fixed in W17:* `5≢` and `①⍕` on an int now throw
   `not a list`, `⎕①≢` works at any size, and an int in the old list band is
   just an int (the list test checks the address too). Before: a list word
   given an int segfaulted, `⎕` with `①`/`②` segfaulted for inputs of about
   95k–102k bytes, and `9223090561878065152 1+Ṅ` crashed.
2. **No gather and no list literal.** *Gather fixed in W17:* `⊇` with a list
   of indices gathers (`minwindow` and `wordbreak` now use it). There is still
   no list literal; a small lookup table cost 23 of `roman`'s 32 bytes.
3. **One accumulator, no rotate.** *Fixed in W17:* `ʘ&` (‹fold2›) and `ʘ^`
   (‹scan2›) carry two accumulators, and `⟲` rotates the top three. Before,
   multi-state DPs (`decode`, `cooldown`, `rob`, `stairs`) and counters
   (`arrows`, `threesum`, `splitarr`, `calc`) went through globals or `⊡` words.
4. **Temporaries are never freed, and `‹slice›` is O(length − i).** *Fixed in
   W17:* a conservative mark-sweep collector runs from `A` (spiral 646 MB →
   about 50 MB), and `‹slice›` copies only its k cells
   (`1000000⍳→l 0 20000⍳⟦←l\\1‹slice›∑+⟧€_` 4.1 s → 0.02 s).
5. **No shift-right-with-fill or prepend**: `1⍳\\⧺`, `0⍆`, `1⍳⧺⌽0⍆` recur in
   `square`, `candy`, `distinct`, `wildcard`, `edit`, `histogram`,
   `maxrect`, `targetsum`, `plusone`.
6. **No short flatten-one-level.** `⧺⍁` is quadratic (12.7 s on a 1000 ×
   1000 grid) and `‹flatten›` is 9 bytes (`change`, `combsum`, `rotate`,
   `largest`).
7. **Missing structures**: no Fenwick tree or merge-count (`smaller` 40,
   `revpairs` 46 and slower than Python), no vectorised bisect (`minsubarr`,
   `lis`, `envelopes`), no island sizes (`maxarea` spells a union-find), no
   spiral, no word-graph neighbours (`ladder` 80), no comparator sort
   (`largest` builds an 18-digit key).
8. **Input and output shapes.** `①` types a one-number line as an int and a
   digit-only line as a number; implicit input arrives only on an empty stack;
   int grids need a size header or `"ℓʘW≢ʘ%`; there is no float output
   (Python's `2.5`/`2.0` cost 18 of `median`'s 26 bytes); implicit output
   prints one value only (`firstlast` spends `Ṅ32)`); `‹words›` drops empty
   lines; `⧺` keeps the text mark only when both sides have it.
9. **Long names without a byte**: `‹isalnum›`, `‹comps›`, `‹diff›`,
   `‹isqrt›`, `‹nextsmaller›`/`‹prevsmaller›`, `‹slice›`; and no select atom,
   no "between", no repeat-n-times adverb, `Ṁ Ṃ` throw on empty, `⊇` takes no
   negative index, and `⟦…⟧⍀⥮` starts no derived verb after a `⟧`.

## W17: the four gaps, and why 21 are slower than Python (2026-11-16)

W17 added a gather (`⊇` with a list of indices), two-accumulator folds and
scans (`ʘ&` ‹fold2›, `ʘ^` ‹scan2›) with a rotate atom `⟲`, an O(k)
`‹slice›`, a conservative mark-and-sweep collector, and the three crash fixes
listed under the gaps above.

**Why 21 were slower.** Each one was re-measured and profiled. Five are
brute force (a, a worse algorithm picked for bytes), nine are implementation
costs in the prelude (b), and seven are noise (c: Golf ties or wins on a
re-measure). Times are the best of 3 wall seconds on the full input, on the
same container, for `main` before W17, this branch, and Python; peak is RSS
in MB.

| problem | class | main s | W17 s | Python s | peak MB | culprit |
|---|---|---|---|---|---|---|
| `spiral` | a | 0.972 | 0.935 | 0.075 | 631 → 125 | peel-and-rotate is O(mn(m+n)); an O(mn) walk costs +71 B |
| `charrep` | a | 0.668 | 0.614 | 0.109 | 393 → 265 | O(26n) vectorised; a two-pointer loop (0.03 s) costs +71 B |
| `wordbreak` | a | 0.700 | 0.764 | 0.208 | 192 → 71 | tries all 40 words at every position; now gathers its windows |
| `minwindow` | a | 0.666 | 0.720 | 0.239 | 342 → 184 | O(n·distinct) vectorised; the emulated gather is now ⊇ |
| `revpairs` | a | 1.429 | 0.384 | 0.849 | 177 → 61 | O(n log² n) bisect per element; the collector's block reuse cut page faults |
| `lastword` | b | 0.509 | 0.667 | 0.130 | 202 → 202 | ‹words› builds 1.2M lists to keep one |
| `roman` | b | 0.354 | 0.564 | 0.188 | 145 → 107 | 2 temporaries per character; a gathered table costs +4 B |
| `ladder` | b | 1.758 | 2.412 | 0.612 | 196 → 204 | dict with list keys; ‹hash› is ~1 µs per key |
| `anagram` | b | 0.292 | 0.306 | 0.151 | 84 → 83 | ② reads a 2M-letter line slowly |
| `largest` | b | 0.531 | 0.577 | 0.296 | 156 → 88 | ⧺ and ↑ on tiny lists per number |
| `balloons` | b | 0.390 | 0.362 | 0.303 | 259 → 150 | ↓ copies and elementwise ops at ~9 ns per cell |
| `longpal` | b | 0.240 | 0.337 | 0.196 | 81 → 81 | ⍋ radix-sorts 5M letters that a counting sort would do |
| `majority` | b | 0.250 | 0.297 | 0.232 | 56 → 55 | dict of 500k keys; `⍋"≢⊘⊇` would be faster |
| `dupe` | b | 0.268 | 0.312 | 0.300 | 49 → 49 | hash set in X/Y scratch cells |
| `dedup` | c | 0.212 | 0.337 | 0.314 | 73 → 73 | noise: Golf ties or wins on a re-measure |
| `plusone` | c | 0.148 | 0.142 | 0.189 | 71 → 71 | noise: Golf ties or wins on a re-measure |
| `water` | c | 0.327 | 0.334 | 0.384 | 75 → 76 | noise: Golf ties or wins on a re-measure |
| `rpn` | c | 0.279 | 0.440 | 0.319 | 86 → 86 | noise: Golf ties or wins on a re-measure |
| `provinces` | c | 0.189 | 0.235 | 0.269 | 107 → 108 | noise: Golf ties or wins on a re-measure |
| `firstuniq` | c | 0.187 | 0.173 | 0.183 | 78 → 78 | noise: Golf ties or wins on a re-measure |
| `median` | c | 0.152 | 0.170 | 0.155 | 45 → 45 | noise: Golf ties or wins on a re-measure |
| **21** | | **10.52** | **11.08** | **5.70** | **3498 → 2262** | |

**What W17 changed.** Memory fell by a third over these 21 (3498 → 2262 MB;
`spiral` 631 → 125 MB, `wordbreak` 192 → 71, `balloons` 259 → 150). `revpairs`
became 3.7× faster than before, because blocks are reused instead of
faulting in fresh pages. Only `minwindow` and `wordbreak` could take a
shorter gather rewrite under their byte ceilings.

**The trade-off.** A collection costs about 5 ns for every live cell it
scans. The first collection waits until 64 MB have been allocated, and each
later one until twice the live heap has been, so a program that stays under
64 MB never collects. A program that passes 64 MB with most of its data
still live pays for one or two scans for nothing: `rpn`, `roman`, `longpal`,
`dedup` and `ladder` lose 0.05–0.65 s. Over the 21 the total went from
10.52 s to 11.08 s. With a 256 MB first step instead, the total is
10.74 s and the memory 3,120 MB: the speed comes back and the memory win
goes, along with the `revpairs` gain. The step is the limit cell 4399488,
so a program can raise it.

**What would close the remaining gap** (none of it costs bytes): a native
memcpy behind `↑ ↓ ⧺` (copies run at 6–12 ns per cell), pointer loops for
elementwise `+ - * ⌈ ⌊` (about 9 ns per cell now), a cheaper list `‹hash›`
(`ladder`), a counting-sort path in `⍋` (`longpal`), and a one-pass
`‹words›` (`lastword`, `rpn`). The brute-force five need longer solutions,
which the byte ceilings rule out. The measured loops (`charrep` 0.03 s,
`spiral` 0.04 s) show that the algorithms themselves are fast in Golf.
