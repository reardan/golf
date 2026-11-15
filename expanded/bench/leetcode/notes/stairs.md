70 Climbing Stairs, Easy. Input: n.
Golf `0①⍳1⟦_\\&+⟧⇤`, 11 bytes: Fibonacci as a fold over `⍳n` that ignores its element (`_`); the accumulator is the current count and the previous one is threaded under the list (`0` pushed first), so the step `p a -> a p+a` is `\\&+`.
Full: `full  golf 0.005s  py 0.015s  OK` (n = 45, LeetCode's limit; n = 80 is an edge case).
Gaps: no "repeat n times" adverb (`‹times›` is 7 bytes) and no pair-state scan, so the second DP value lives under the fold's list; `0` cannot go under implicit input without `①` (or `0\\`). The vector form `2⍳⟦_⌽+⍀⟧…Ṁ` is a byte longer.
