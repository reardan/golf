44 Wildcard Matching, Hard. Input: s on line 1, p on line 2 (either may be empty); prints true/false.
Golf `②①≢ʀ⟦"42-[_⌊⍀⋄62-①62-\\%⌈1⍳⊕\\⧺]⟧⇤ʘ$ṭ`, 35 bytes: a fold over the pattern of the row `dp[j]` (p so far matches `s[:j]`), with 0 for true and a positive number for false, so the first row is just `ʀ` of `|s|`, AND is `⌈` and OR is `⌊`. `*` is the prefix OR `⌊⍀`; any other char is `[1] ⧺ (row ⌈ M)`, M being `(s−62) % (c−62)`, zero exactly when `s` is `c` or `c` is `?` (`?` − 62 = 1). The last cell goes to `ṭ`.
Full: `full  golf 0.120s  py 0.172s  OK` (|s| = 2000, |p| = 1292, a match).
Gaps: no shift-right-with-fill (`1⍳⊕\\⧺`, 5 bytes) and no per-char branch adverb (`"42-[…⋄…]`); `①`/`②` saved the line reading.
