**84 Largest Rectangle in Histogram** (Hard). Input: the heights, whitespace-separated. Output the largest area.
Golf `1⍳⧺⌽0⍆"±ʘn⥮+&≢-*Ṁ` (17 bytes): `1⍳⧺⌽0⍆` puts a `0` at both ends; `±ʘn` (next greater of the negated heights) is the next smaller bar, and `⥮` runs it from the right too, giving `N-1-prev`; so `a + b - N` is each bar's width between its smaller neighbours, times its height, maximised. The ends are reversed, which does not change the answer.
Full (500k heights up to 10^4): `full  golf 0.159s  py 0.207s  OK`.
**Gaps:** no digraph for `‹nextsmaller›`/`‹prevsmaller›` (13 bytes each), hence `±ʘn⥮`; "none" is `-1` where the width formula wants `n`, which costs the 6-byte sentinel padding (there is no prepend: `1⍳⧺` appends, `⌽` turns it round).
