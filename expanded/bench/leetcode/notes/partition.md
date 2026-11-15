416 Partition Equal Subset Sum, Medium. Input: the numbers.
Golf `∑ʀ⟦⊗⍳⊕&⧺⌊⟧⇤ʘ$ṭ`, 14 bytes: subset-sum DP as one vector per number. The reachable sums of the doubled numbers are the `0`s of a list over `0 … Σ` (start: `∑ʀ`, only `0` is 0); each `x` shifts the list right by `2x` with positive filler (`⊗⍳⊕&⧺`) and takes the elementwise minimum, `⌊` stopping at the shorter list. The last entry is `0` exactly when `Σ = 2·(subset sum)`, which also makes an odd total false. O(n·Σ).
`full  golf 0.068s  py 0.108s  OK` (200 numbers in 1 … 100, LeetCode's limits).
Gaps: none (no shift-with-fill word, so the shift is `⍳ … ⧺`).
