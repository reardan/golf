**152 Maximum Product Subarray** (Medium). Input: the numbers, whitespace-separated. Output the largest product.
Golf `:f\\1⊔*;f⍀⥮⌈Ṁ` (12 bytes): the two-pass solution: a prefix-product scan that restarts after a zero (`f` multiplies `x` by `acc ⊔ 1`, the unsigned max, which turns only `0` into `1`), run both ways with `⥮`; the answer is the largest entry of either.
Full (1M values, zero-separated runs whose products fit 32 bits, as LeetCode promises): `full  golf 0.115s  py 0.367s  OK`.
**Gaps:** `⟦…⟧⍀⥮` does not chain (a `⟧` starts no derived verb), so the scan function needs a named word (`:f…;f⍀⥮`) or a second block, 2 bytes either way.
