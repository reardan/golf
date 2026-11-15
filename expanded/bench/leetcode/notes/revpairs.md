493 Reverse Pairs, Hard. Input: the nums.
Golf `⊡r⇒ll≢⊖[0^]l"≢⊘↑⇒ala≢↓⇒barbr+b⊗⍋⇒sa⟦s\\ʘb⟧€∑+;r`, 46 bytes: divide and conquer, `r(l) = r(a) + r(b) + Σ_{x∈a} #{y∈b : 2y < x}`, the cross term a bisect of each `x` into `sorted(2b)` (the block reads the local `s`). O(n log² n).
Timing: `full  golf 1.148s  py 0.702s  OK` (300k ints in ±2^31). Golf is slower here: about 2n recursive calls on small lists plus one bisect call per element per level.
Gaps: no Fenwick tree / order-statistics structure and no "count pairs across two sorted lists" (merge-count) word; no vectorised bisect (`ʘb` of a list of queries), so the cross count is a block call per element.
