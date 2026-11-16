62 Unique Paths, Medium. Input: `m n`.
Golf `⍘⍳\\∑⍳0≡⟦_+⍀⟧⇤Ṃ±`, 15 bytes: start from the unit row `[-1 0 … 0]` of length n (`∑⍳0≡`) and take the prefix sum m times (a fold over `⍳m`); the row is then minus the binomials, so the answer is `Ṃ±`.
Full: `full  golf 0.041s  py 0.111s  OK` (m = 300000, n = 4: the O(mn) DP, answer 4.5e15).
Gaps: `⍘` gives `n` back as a one-element list, so `\\∑` to make it an int; no "repeat n times" adverb (fold over `⍳m` with `_`).
