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

## Micro, ns per element

| Wave | loop | iota | sum | map | fold | filter | vadd | dictput |
|---|---|---|---|---|---|---|---|---|
| W12-0, 2026-11-08 | 1.12 | 8.33 | 20.43 | 24.33 | 21.61 | 25.74 | 39.69 | 555.32 |
| W12-O1, 2026-11-08 | 1.12 | 9.24 | 19.77 | 24.08 | 21.54 | 25.18 | 41.15 | 552.18 |

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
