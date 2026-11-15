312 Burst Balloons, Hard. Input: the numbers.
Golf `⊡f_⇒v"⇒av⟦⊕a\\↓a"v≢⊕↓**+⟧⍸v⌽ℑ⊕↓⊞+⌈⍁v\\⍆;⌽1⍆⌽1⍆"2↓&0*Ṿ\\⍆f⇤ʘ$Ṁ`, 58 bytes: interval DP by diagonals. `a` is the input padded with 1s (`⌽1⍆⌽1⍆`); `v` holds `D_1 … D_{L-1}`, `D_d[l] = dp[l][l+d]`. For each length `L` (`L = ≢v+1`), `D_L = max_d (D_d + D_{L-d}↓d + (a↓d)·a·(a↓L))`, all `d` at once: `⍸` over `v` adds the products, `⌽v` zipped with `1 … L-1` under `↓` gives the shifted partners, `⌈⍁` takes the elementwise max (lengths truncate to the shorter). O(n³) work in O(n²) vector ops.
`full  golf 0.337s  py 0.264s  OK` (250 balloons in 0 … 100; 265 MB peak).
Gaps: `⊞` cannot broadcast one list against a list of lists (it zips), so `(a↓d)·A` per `d` needs a `⍸` block; no interval-DP word; temporaries are never freed (265 MB on n = 250).
