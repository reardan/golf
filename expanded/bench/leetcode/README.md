# LeetCode benchmark — Golf vs Python, C++ and Jelly

Ten LeetCode problems (3 easy, 4 medium, 3 hard), each solved in Golf, Python
(idiomatic `py/` and golfed `pyg/`), C++ and Jelly. Every program reads stdin
(Jelly takes arguments, the usual Jelly way) and prints the answer. This is the
baseline [`../../PLAN_W12.md`](../../PLAN_W12.md) measures itself against.

```sh
./build.sh                  # golfc every golf/*.golfj, g++ -O2 every cpp/*.cpp, into bin/
python3 gen.py 1 in         # the large inputs (~26 MB); `gen.py 0.001 small` for tiny ones
./bench.sh in               # golf / py / cpp: outputs must agree, best-of-3 wall seconds
./bytes.sh                  # sizes: golf code-page bytes, pyg, py, cpp, jelly
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

### Byte ceilings

The current size of each Golf solution, as `./bytes.sh` counts it. The gate
(`test/run2.sh`, block W12-O4) compiles every solution, checks its answer
against `py/` on `gen.py 0.001` inputs, and fails if a solution is larger than
its number here. A solution may only get shorter: when one shrinks, lower its
number.

| problem | bytes |
|---|---|
| twosum | 54 |
| parens | 41 |
| stock | 10 |
| longsub | 42 |
| prodself | 27 |
| topk | 31 |
| islands | 101 |
| trap | 16 |
| slidemax | 11 |
| queens | 78 |

Total 411 (655 before W12-6's rewrite, 898 at the baseline above).

### Notes
W12-6 rewrote all ten with the W12 words and the one-byte aliases
`ℤ ⎕ ⏎ Ḋ Ġ Ṗ Ḳ Ḃ Ṿ` (655 → 411 bytes; timings in `../RESULTS.md`, "W12
final"). Stock, Trap and Sliding Window are explained in REFERENCE.md §4,
"LeetCode in Golf". Two of them use details worth knowing. `islands` marks
land as visited (`48⍈`) while `⍸` is still walking the grid, and its word
tests the element `⍸` hands it, so it relies on `⍸` reading each element
when it reaches it, as it does. `parens` starts its stack as `1⍳` (a
sentinel `0`) and pushes two more `0`s on a mismatch, so a pop never finds it
empty and the answer is just "is one element left". `prodself` stays general
(prefix and suffix products) rather than use the input's ±1 values, where
`ℤ"∏*⍕` would do in 5 bytes.

`golf/stock_stream.golfj` (W12-A8) is Stock as a stream, `‹sints›′p‹smap›0′⌈‹sfold›`
with the running minimum threaded under the pipeline: 40 bytes, about 0.09 s
and 13 MB peak on the `stock` input, against `stock.golfj`'s 0.07 s and 32 MB
(both measured after W12-P1), and constant memory however long the input. It
is not one of the ten that `bench.sh` runs.

`golf/stream_ints_proto.golfj` is the 2-line `‹getc›` integer reader that
reads the `stock` input in 0.07 s and 13 MB, against `‹ints›`'s 0.52 s and
179 MB: the evidence for PLAN_W12's P1. The full write-up, with the Jelly
timings and per-problem notes, is the doc linked from PLAN_W12.md.
