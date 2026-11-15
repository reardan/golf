188 Best Time to Buy and Sell Stock IV, Hard. Input: `k`, then the prices.
Golf `⍘⍳0⟦_&-⌈⍀&+⌈⍀⟧⇤Ṁ`, 16 bytes: one transaction layer at a time. With `S` the best profit by each day using `j` transactions, the next layer is `⌈⍀(P + ⌈⍀(S - P))`: buy at the best `S[t] - P[t]` so far, sell today, keep the running best. Folded `k` times over `⍳k` from `S = 0` (a scalar, which broadcasts), with the prices threaded under; `Ṁ` of the last layer. O(nk) as vector ops.
`full  golf 0.041s  py 0.192s  OK` (20k prices up to 1000, k = 40).
Gaps: none.
