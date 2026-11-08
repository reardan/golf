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
```

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

### Byte ceilings

The current size of each Golf solution, as `./bytes.sh` counts it. The gate
(`test/run2.sh`, block W12-O4) compiles every solution, checks its answer
against `py/` on `gen.py 0.001` inputs (and the small edge cases `gen.py`
writes as `name2.txt`, `name3.txt` …), and fails if a solution is larger
than its number here. A solution may only get shorter: when one shrinks,
lower its number.

| problem | bytes |
|---|---|
| twosum | 32 |
| parens | 22 |
| stock | 6 |
| longsub | 9 |
| prodself | 12 |
| topk | 17 |
| islands | 7 |
| trap | 11 |
| slidemax | 4 |
| queens | 57 |
| search | 4 |
| koko | 25 |
| oranges | 121 |
| course | 15 |
| delay | 28 |
| redundant | 33 |
| coins | 54 |
| lcs | 33 |
| temps | 7 |
| bits | 6 |

Total 503: the first ten 177 (411 before W13-F's rewrite, 655 before
W12-6's, 898 at the baseline above), the second ten 326.

### Notes

W13-F rewrote the first ten with the W13 language: adverbs that quote the
word before them (`⌊⍀` is `′⌊⍀`), `⟦ … ⟧` blocks, implicit output (none of
them ends in `Ṅ` or `⍕` any more), bare locals, the one-byte words
`Ṁ ⍘ ⍂ ⍃ Ċ ⍖ Ṕ ℑ Ǧ ṭ`, the digraphs and the bit atoms. Each keeps its
algorithm's time complexity. Stock, Trap and Sliding Window are explained in
REFERENCE.md §4, "LeetCode in Golf". The others:

- **twosum** `Ḋℤ⍘\\⊗-⟦…⟧⍷`. `\\⊗-` turns each `x` into `z = t - 2x`, so
  two numbers sum to `t` exactly when their `z`s are negatives of each other
  and the block never needs `t`. `⍷` walks the `z`s with the dict under
  them: a miss stores `z → i+1` (`⇡i←iṖ`) and answers non-zero, a hit
  prints `j` and a space and answers `0`, which stops `⍷`. `≡` makes that
  `0` out of the dict and `z`, which are never equal, so the dict is gone
  and implicit output prints `⍷`'s index `i`.
- **parens** `⏎\\⟦⊖⊘"1$[-⊕]"[⋄"]⟧€&ṭ⊐` uses the data stack itself as the
  bracket stack: `€`'s function sees the stack under its element (the
  threading contract) and may leave values there. `⊖⊘` maps `( [ {` to
  19 45 61 and `) ] }` to one more, 20 46 62 (found by a brute-force
  search). An opener (odd) stays on the stack; a closer subtracts itself
  from the top and adds 1, which is `0` exactly for its own opener, and
  `"[⋄"]` keeps any non-zero value (an opener, or the remains of a
  mismatch, which nothing can ever match) and drops a `0`. `⏎`'s flag `0`
  sits at the bottom, so the input is valid exactly when that `0` is right
  under `€`'s result: `&ṭ⊐`. Two values are left, so nothing more prints.
  The stack is the process stack: about a million unclosed openers is the
  limit (`((((`… 4M deep segfaults).
- **longsub** `⏎_Ṕ⌈⍀ℑ\\-Ṁ`. `Ṕ` gives each letter's previous position,
  `⌈⍀` the running maximum of those, the start of the window ending at `i`
  less one, and `ℑ\\-` turns that into the window lengths. `⏎_` reads the
  line without its newline (`⎕` would count it).
- **prodself** `ℤ"1*⍃\\⌽1*⍃⌽*`: the exclusive prefix products times the
  exclusive suffix products. It stays general rather than use the input's
  ±1 values, where `ℤ"∏*` would do.
- **topk** `ℤ⍘\\Ċ"Ḳ⍋⟦&\\Ġ⟧⍖\\_\\↑`: count, sort the distinct values, then a
  stable descending sort by count (`⍖`, its key reads the dict under the
  keys), so ties stay in value order, as Python's `(-count, value)` key has
  them. `ℤ⍘\\"ĊḲ⍋\\⧺\\ʘk` (12 bytes: `‹mostcommon›` of the sorted distinct
  values followed by the input, whose ties fall in first-appearance order,
  i.e. value order) gives the same answer but counts twice and runs in
  0.10 s, slower than Python's 0.09.
- **islands** `⎕ʘW′⊣ʘ7`: `‹words›` splits the grid into rows, and
  `‹gcomps›` counts the components of the cells its predicate accepts.
  The predicate is the trailing-zero-count atom `⊣`, which is `0` for `1`
  (49, odd) and not for `0` (48) or the newline (10).
- **queens** keeps the free columns `c` (not the used ones) and the two
  diagonals as bare locals, so the full mask is only the first call's
  argument (`ℤ∑1\\≪⊖0"s`) and the count is just `c0≡±` at the leaves. `⊥`
  takes the lowest free bit, `⊗` and `⊘` shift the diagonals.

The second ten, one library word each:

- **search** `ℤ⍘ʘb` is `‹bisect›`; **temps** `ℤʘnℑ-0⌈` is
  `‹nextgreater›` less the index, clamped at `0`; **bits** `ℤ∑⊕⍳♯€` maps
  the popcount atom over `0 … n`.
- **koko** binary-searches the speed with `‹bsearch›` (`ʘh`) over
  `[1, max)`: the predicate sees the piles and `h` under its argument and
  answers "the hours exceed `h`" (`&≻`), `0` once the speed is enough.
- **course** `ℤ""⍘\\‹dadj›ʘoṭ⊐`: `‹toposort›` fails exactly when there is a
  cycle, whichever way the edges point. The two copies of the input under it
  keep implicit output from printing the order.
- **delay** `‹dwadj›` and `‹dijkstra›` (`ʘw`) from `k`, the 1-based list
  less its vertex 0, then `-1` if the minimum is `-1`, else the maximum.
- **redundant** `‹uf›`, `‹chunk›` into pairs and `⍷` over them: the first
  pair `‹uunion›` (`ʘu`) finds already joined is the answer (the predicate
  keeps it in `p`).
- **coins** `‹table1›` (`ʘt`): `t[i]` is the least `t[i-c]+1` over the
  coins, an out-of-range coin giving `i<<40` (so `t[0]` is `0` and an
  unreachable amount is at least 2^40).
- **lcs** folds one row per letter of the first string with `⇤`: with `P`
  the previous row (non-decreasing), the new one is
  `⌈⍀ max(P, (0⌈⍃ P) + E)`, where `0⌈⍃` shifts `P` right by one and `E`
  is 1 where the second string has the letter. That is the textbook
  recurrence, because LCS rows grow by at most one per step. O(mn), like the
  `‹table2›` form, with vector ops in place of a call per cell.
- **oranges** builds the grid's graph and runs `‹bfs›` from a virtual source
  joined to every rotten orange. On the input as one code list (rows of
  width `W`, the newline a wall), `f` (under `⍸`) adds the edges to the
  right and below of each orange through `e`, which checks the neighbour
  (the list is padded with zeros so that `p+W` is always in range), and the
  answer is the largest distance over the fresh oranges less one, or `-1`
  when one is unreachable.

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
