96 Unique Binary Search Trees, Medium. Input: n.
Golf `∑⊕⟦_"⌽*∑1⌈⟧ʘtṀ`, 14 bytes: the Catalan DP with `‹table1›` (`ʘt`) over n+1 entries: `t[i] = Σ t[j]·t[i-1-j]`, the dot product of the table so far with its reverse (`"⌽*∑`), and `1⌈` makes `t[0] = 1`; Catalan numbers grow, so `Ṁ` is the last.
Full: `full  golf 0.006s  py 0.017s  OK` (n = 19, LeetCode's limit; n = 35 is an edge case).
Gaps: none (the step must drop the index it is given, `_`).
