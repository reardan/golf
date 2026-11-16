215 Kth Largest Element in an Array, Medium. Input: `k`, then the numbers.
Golf `⍘±\\⍋\\↑Ṃ`, 7 bytes: `⍘` splits off `k`, `±\\⍋\\↑` sorts (radix, linear) and takes the last k, `Ṃ` is the smallest of those.
Full: `full  golf 0.165s  py 0.346s  OK` (1M numbers in ±10^4, random k).
Gaps: `⊇` does not take a negative index (`l -k⊇` would be 6 bytes, `l 0 1-⊇` is `index out of range`).
