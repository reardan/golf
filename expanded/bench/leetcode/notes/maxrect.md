**85 Maximal Rectangle** (Hard). Input: the 0/1 grid, one row per line, no spaces. Output the largest all-1 area.
Golf `⎕ʘW2%⟦\\⊕*⟧⍀⟦1⍳⧺⌽0⍆"±ʘn⥮+&≢-*Ṁ⟧€Ṁ` (32 bytes): the rows as 0/1 (`2%` of the codes), a scan down the rows makes the column heights (`(acc+1)*row`), and each row's heights go through the histogram solution (`histogram.golfj`), maximised.
Full (1000 × 1000, 80% ones): `full  golf 0.203s  py 0.453s  OK`.
**Gaps:** the histogram part has no word of its own, so it is spelled out inside the block (same gaps as `histogram`); the grid starts with a digit, so it is read with `⎕` rather than implicit input.
