518 Coin Change II, Medium. Input: amount, then the coins.
Golf `⍘ʀ0≡⟦ʘ%+⍀‹flatten›⟧⇤ʘ$±`, 23 bytes: for each coin `c`, `dp[a] += dp[a-c]` is a prefix sum along each residue class mod `c`: cut dp into rows of `c` (`ʘ%`), running-sum the rows (`+⍀`; the short last row cuts the sum), flatten back. Seeded `-1`, so `±` at the end.
Timing: `full  golf 0.040s  py 0.160s  OK` (amount 100k, 12 coins, answer about 2^35).
Gaps: `‹flatten›` has no short spelling (9 of the 23 bytes; `⧺⍁` is 2 but quadratic in the number of rows); no strided scan.
