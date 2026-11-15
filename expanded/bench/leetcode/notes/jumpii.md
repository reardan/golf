45 Jump Game II, Medium. Input: the jump lengths (the end is always reachable). Output: the minimum number of jumps.
Golf `ℑ+⌈⍀"≢"⊖⟦&\\ʘb1⍳+⟧ʘ>0⊇`, 21 bytes: `M = ⌈⍀(i + a[i])`; the first index that can reach `v` is `‹bisect›(M, v)`, and walking that back from `n-1` is optimal, so it is a BFS (`ʘ>`) from `n-1` whose only neighbour of `v` is `[bisect(M, v)]` (`&\\ʘb1⍳+`, M read from under `n`), and the answer is the distance to 0. O(n + jumps·log n).
`full  golf 0.108s  py 0.202s  OK` (1M lengths, mostly 0..6, 1% up to 1000).
Gaps: no "iterate until fixed, counting the steps" (`⍣` with a counter is 23 bytes), so the chain is a BFS; `‹bfsf›`'s function must return a list even for one neighbour (`1⍳+`); the natural BFS over `[v+1, v+a[v]]` (`≢0⟦"⊇⍳+⊕⟧ʘ>ʘ$`, 13 bytes) is O(Σa).
