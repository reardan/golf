53 Maximum Subarray, Medium. Input: the numbers.
Golf `⟦\\0⌈+⟧⍀Ṁ`, 8 bytes: Kadane as a scan, the best sum ending at each index is `max(acc, 0) + x` (`\\0⌈+`), and `Ṁ` takes the largest. (`+⍀"0⌊⍃-Ṁ`, prefix sums less the exclusive running minimum seeded with 0, is also 8.)
`full  golf 0.085s  py 0.303s  OK` (1M ints in ±10^4).
Gaps: none (the step needs a block because `⍀` passes `acc x` and the clamp is on `acc`).
