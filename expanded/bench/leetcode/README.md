# LeetCode benchmark — Golf vs Python, C++ and Jelly

Twenty LeetCode problems, each solved in Golf, Python (idiomatic `py/` and
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
| parens | 10 |
| stock | 4 |
| longsub | 9 |
| prodself | 7 |
| topk | 6 |
| islands | 7 |
| trap | 9 |
| slidemax | 3 |
| queens | 56 |
| search | 3 |
| koko | 21 |
| oranges | 12 |
| course | 10 |
| delay | 16 |
| redundant | 16 |
| coins | 11 |
| lcs | 24 |
| temps | 6 |
| bits | 5 |

Total 239: the first ten 115 (177 before W15's rewrite, 411 before
W13-F's, 655 before W12-6's, 898 at the baseline above), the second ten
124 (326 before W15).

### Notes

W15 rewrote all twenty with implicit input (no program starts with `ℤ` any
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
- **parens** `⊖⊘⟦-⊕⟧⍙≢ṭ⊐`. `⊖⊘` maps `( [ {` to 19 45 61 and `) ] }` to
  one more, 20 46 62 (found by a brute-force search). `⍙` is the stack
  cancel: an element cancels the stack top `t` when `t x - ⊕` is `0`, which
  is exactly a closer on its own opener; anything else is pushed and can
  never be cancelled later. The string is valid when nothing is left:
  `≢ṭ⊐`. The stack is a heap block now, so depth is not limited by the
  process stack. (Brackets never start with a digit or `-`, so the line
  arrives as implicit input.)
- **longsub** `⏎_Ṕ⌈⍀ℑ\\-Ṁ`. `Ṕ` gives each letter's previous position,
  `⌈⍀` the running maximum of those, the start of the window ending at `i`
  less one, and `ℑ\\-` turns that into the window lengths. It keeps its
  explicit `⏎_`: the string may begin with a digit, which implicit input
  would read as numbers. Since W15 `Ṕ` uses a table instead of a dict when
  the values span a small range.
- **prodself** `⟦1*⍃⟧⥮*`: `1*⍃` is the exclusive prefix product, `⥮` runs
  it from both ends, `*` multiplies the two. No division, so zeros are fine.
- **topk** `⍘\\⍋\\ʘk`: sort the numbers, then `‹mostcommon›`, whose ties
  fall in first-appearance order, which after the sort is value order, as
  Python's `(-count, value)` key has them. The radix sort is one pass here,
  and `‹mostcommon›` counts small-range values in a table.
- **islands** `⎕ʘW′⊣ʘ7`: `‹words›` splits the grid into rows, and
  `‹gcomps›` counts the components of the cells its predicate accepts.
  The predicate is the trailing-zero-count atom `⊣`, which is `0` for `1`
  (49, odd) and not for `0` (48) or the newline (10). (It reads with `⎕`:
  the grid starts with a digit.)
- **queens** keeps the free columns `c` (not the used ones) and the two
  diagonals as bare locals, so the full mask is only the first call's
  argument (`∑1\\≪⊖0"s`, `∑` of the one-number input being `n`) and the
  count is just `c0≡±` at the leaves. `⊥` takes the lowest free bit, `⊗` and
  `⊘` shift the diagonals.

The second ten:

- **search** `⍘ʘb` is `‹bisect›`; **temps** `ʘnℑ-0⌈` is `‹nextgreater›`
  less the index, clamped at `0`; **bits** `∑⊕⍳♯€` maps the popcount atom
  over `0 … n`.
- **koko** `⍘&Ṁ1\\⟦→k&⊖←k/⊞⊕∑&≻⟧ʘh` binary-searches the speed with
  `‹bsearch›` (`ʘh`) over `[1, max)`. The predicate computes the hours as
  vector arithmetic on the piles under it, `(p-1)/k+1` summed, with `/⊞`
  broadcasting the scalar `k`, and answers "the hours exceed `h`" (`&≻`).
- **oranges** `⎕ʘW50 48ʘ@⊔⍁`: `‹gdist›` (`ʘ@`) is the multi-source grid BFS,
  from every `2` (code 50), with `0` (48) as the wall. `⊔⍁` reduces the
  distances with the raw, unsigned maximum: the answer is the largest
  distance, and a fresh orange that nothing reaches is `-1`, which as an
  unsigned number beats every distance, so the answer is then `-1`.
- **course** `⍘\\ʘ/ʘo\\_ṭ⊐`: `‹dadj›` (`ʘ/`) builds the graph and
  `‹toposort›` fails exactly when there is a cycle.
- **delay** `⍘⊕\\⍘→kʘ|←kʘw1↓⊔⍁`: `‹dwadj›` (`ʘ|`) and `‹dijkstra›` (`ʘw`)
  from `k`, the 1-based list less its vertex 0, then `⊔⍁` again: the
  largest distance, or `-1` if any vertex is unreached.
- **redundant** `⍘⊕ʘ=\\2ʘ%⟦ʘu⊖⟧⌿0⊇`: a union-find (`ʘ=`), the edges as
  pairs (`2ʘ%`), filtered through `‹uunion›`, which takes a pair since W15
  and answers `1` for an edge whose ends were already joined; `⊖` makes
  that the `0` that `⌿` keeps. The first one kept is the answer.
- **coins** `⍘⊕0⟦&+⟧ʘ>ʘ$`: Coin Change is a shortest path. The vertices are
  the amounts `0 … amount`, `&+` adds every coin to an amount, and `‹bfsf›`
  (`ʘ>`) is BFS over that function from `0`; `ʘ$` takes the last distance,
  `-1` when the amount cannot be made.
- **lcs** `⏎_"→b0*⟦&0⌈⍃\\←b≡⊞-⌈⌈⍀⟧⇤Ṁ` folds one row per letter of the
  second string (the fold's list is implicit input: `⏎_` took the first
  line, so the look-ahead gives the second). With `P` the previous row
  (non-decreasing), the new one is `⌈⍀ max(P, (0⌈⍃ P) + E)`, where `0⌈⍃`
  shifts `P` right by one and `E` is 1 where the other string has the
  letter (`≡⊞` broadcasts the letter; true is `-1`, hence `-`). O(mn), with
  vector ops in place of a call per cell.

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
| Nibbles | 92 | 220 |
| Vyxal | 99 | 297 |
| Golf | 115 | 239 |
| 05AB1E | 136 | 364 |
| Jelly | 144 | — |

Per problem (Golf / Vyxal / 05AB1E / Nibbles): twosum 4/12/14/8, parens
10/2/8/13, stock 4/5/6/5, longsub 9/8/9/9, prodself 7/6/8/3, topk 6/11/10/8,
islands 7/26/41/20, trap 9/12/16/8, slidemax 3/3/5/6, queens 56/14/19/12,
search 3/2/2/3, koko 21/16/19/14, oranges 12/38/54/21, course 10/15/15/10,
delay 16/54/57/31, redundant 16/15/15/9, coins 11/21/26/12, lcs 24/26/24/16,
temps 6/8/11/7, bits 5/3/5/5.

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
