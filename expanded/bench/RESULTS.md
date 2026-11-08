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

## Micro, ns per element

| Wave | loop | iota | sum | map | fold | filter | vadd | dictput |
|---|---|---|---|---|---|---|---|---|
| W12-0, 2026-11-08 | 1.12 | 8.33 | 20.43 | 24.33 | 21.61 | 25.74 | 39.69 | 555.32 |
| W12-O1, 2026-11-08 | 1.12 | 9.24 | 19.77 | 24.08 | 21.54 | 25.18 | 41.15 | 552.18 |
| W12-P3 before (base 7a867ca), 2026-11-08 | 1.05 | 8.70 | 19.77 | 25.12 | 21.31 | 26.64 | 40.53 | — |
| W12-P3, 2026-11-08 | 1.01 | 6.96 | 10.52 | 15.59 | 11.61 | 15.00 | 17.97 | — |

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
