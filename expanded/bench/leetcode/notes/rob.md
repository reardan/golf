198 House Robber, Medium. Input: the amounts.
Golf `0\\0⟦+&⌈\\⟧⇤⌈`, 11 bytes: a fold whose accumulator is dp[i-2] and which keeps dp[i-1] under the list (the threading contract): the step `B A x -> max(B, A+x) B` is `+&⌈\\`. `0\\` puts the starting 0 under the input, and the last `⌈` takes the larger of the two values left.
Full: `full  golf 0.062s  py 0.173s  OK` (1M amounts).
Gaps: two-variable DP state has to be threaded under the fold's list; there is no pair-state scan, and pushing the 0 under the implicit input costs `0\\`.
