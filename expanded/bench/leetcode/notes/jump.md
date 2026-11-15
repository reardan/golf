55 Jump Game, Medium. Input: the jump lengths. Output: true/false.
Golf `ℑ+0⌈⍃ℑ≺Ṃṭ`, 9 bytes: `ℑ+` is `i + a[i]`, `0⌈⍃` its exclusive running maximum (the furthest index reachable before `i`), `ℑ≺` flags the indices beyond it, `Ṃ` is -1 if any is, and `ṭ` prints the flag. O(n).
`full  golf 0.097s  py 0.207s  OK` (1M lengths in 0..3, blocked 50 before the end).
Gaps: none.
