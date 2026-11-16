315 Count of Smaller Numbers After Self, Hard. Input: the numbers.
Golf `Ḋ\\ʘVʘV⟦"0⊣²²+→i{&←i2ʘd&→i[Ḃ_⋄0Ǧ-]←i1≡}⟧€`, 40 bytes: ranks by a double grade (ties by index, so an equal later value never counts), then left to right a segment-tree walk in a dict: from leaf `2^24 + r` (`0⊣²²` is `64⁴`) up to the root, a left child bumps its parent's left count and a right child subtracts it. Starting from `r` (the number of smaller ranks overall), this leaves the number of smaller ranks after `i`. O(n log N).
`full  golf 0.182s  py 0.285s  OK` (100k ints in ±10^4).
Gaps: no Fenwick / order-statistics tree or merge-count word, so the tree is spelled out as a `{ }` loop on a global; `⟦ ⟧` blocks cannot write locals; no cheap power-of-two constant (`0⊣²²`).
