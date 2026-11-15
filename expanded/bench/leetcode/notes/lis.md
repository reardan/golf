300 Longest Increasing Subsequence, Medium. Input: the numbers.
Golf `Ṁ⊕-"0*⟦&&ʘb\\⍈⟧⇤ʘ?≢`, 18 bytes: patience sorting, O(n log n). `Ṁ⊕-` shifts every value below 0 so that a list of `n` zeros (`"0*`) is a sorted "tails" array padded with +infinity; the fold stores each `x` at its lower bound (`&&ʘb\\⍈`), and `ʘ?≢` counts the non-zero (used) tails.
`full  golf 0.397s  py 0.408s  OK` (1M ints in ±10^4).
Gaps: no "store at the bisect point, or append if it is the end" word (`⍈` refuses index `≢l`, `⍆` only appends), so the tails array is preallocated and the values shifted to fit under a 0 sentinel; no cheap +infinity list.
