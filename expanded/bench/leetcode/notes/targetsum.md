494 Target Sum, Medium. Input: target, then the nums.
Golf `⍘_"∑ʀ0≡⟦⍳0*&⧺+⟧⇤ℑ"⌽-①≡*∑`, 24 bytes: subset-sum counting `dp` over `0 … S` (seeded `-1` at 0, `ʀ0≡`), each step `dp + (x zeros ⧺ dp)` (the `+` cuts to the shorter length); then the answer is `Σ dp[i]·[2i - S = target]` (`ℑ"⌽-` is `2i - S`), which needs no parity or range check.
Timing: `full  golf 0.100s  py 0.157s  OK` (40 nums up to 5000).
Gaps: no "shift right by k with zero fill" word (`⍳0*&⧺` is 5 bytes); `⊇` has no default for an out-of-range index, so indexing dp at (S+t)/2 would need explicit bounds/parity tests (worked around with the mask dot product).
