221 Maximal Square, Medium. Input: the 0/1 grid, one row per line, no spaces. Output: the area.
Golf `⎕ʘW2%⟦\\1⍳\\⧺2⌊⊟⊕*⟦\\⊕⌊⟧⍀⟧⍀Ṁ€Ṁ²`, 28 bytes. `⎕ʘW2%` reads the rows as 0/1 lists. The outer `⍀` scans the rows, the previous dp row P with the cells C: `1⍳\\⧺2⌊⊟⊕` is 1 + min(P[j-1], P[j]) (a 0 in front, then a width-2 window minimum), `*` zeros it where C is 0, and the inner scan `⟦\\⊕⌊⟧⍀` is R[j] = min(R[j-1]+1, that). `Ṁ€Ṁ²` is the largest side, squared. O(cells).
Full: `full  golf 0.141s  py 0.223s  OK` (1000 × 1000, 92% ones).
Gaps: no "shift right with a fill" word (`1⍳\\⧺` + window, or `0⟦\\_⟧⍃`, for what Jelly/APL write in 2 bytes); there is no atom that returns its right operand, so `⍃` cannot shift without a block.
