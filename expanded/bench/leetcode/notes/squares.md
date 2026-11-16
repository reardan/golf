279 Perfect Squares, Medium. Input: `n`.
Golf `∑"ʀ²⟦&≻⟧⌿\\⊕0⟦&+⟧ʘ>ʘ$`, 20 bytes: as Coin Change, a BFS over the amounts `0 … n` (`ʘ>`), the neighbours of `v` being `v` plus every square; the squares are `0² … n²` filtered to those `≤ n` (`⟦&≻⟧⌿`), so the BFS is O(n√n). `ʘ$` is the distance of `n`.
`full  golf 0.063s  py 0.239s  OK` (n = 29999, a `8b+7` number, answer 4).
Gaps: `‹isqrt›` has no digraph (`‹isqrt›ʀ²` would be 9 bytes, the filter is 7).
