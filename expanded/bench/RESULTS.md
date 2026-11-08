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

## Micro, ns per element

| Wave | loop | iota | sum | map | fold | filter | vadd | dictput |
|---|---|---|---|---|---|---|---|---|
| W12-0, 2026-11-08 | 1.12 | 8.33 | 20.43 | 24.33 | 21.61 | 25.74 | 39.69 | 555.32 |
