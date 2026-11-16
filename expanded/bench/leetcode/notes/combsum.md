39 Combination Sum, Medium (prints the number of combinations). Input: target, then the distinct candidates (target 10^5, 20 candidates from 5000…25000, so the count fits 64 bits).
Golf `⍘ʀ0≡±⟦ʘ%+⍀⧺⍁⟧⇤ʘ$`, 16 bytes: Coin Change II. `dp = [1 0 … 0]` (`ʀ0≡±`); for each candidate c, `ʘ%` cuts dp into rows of c, the running sum of the rows `+⍀` (list + list, the last row shorter) is `dp[s] += dp[s-c]` down every residue, and `⧺⍁` joins the rows back. The answer is the last entry.
Full: `full  golf 0.138s  py 0.145s  OK`
Gaps: no cheap linear flatten: `⧺⍁` re-copies the prefix, O(T²/c) per candidate (0.12 s and 101 MB peak here; `‹flatten›` is O(T), 0.07 s and 47 MB, but 9 bytes instead of 2).
