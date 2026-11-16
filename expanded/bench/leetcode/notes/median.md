4 Median of Two Sorted Arrays, Hard. Input: the two arrays, one per line (a line may be empty); 500k + 500k values in ±10^6. Output as Python prints the float (`2.0`, `-0.5`).
Golf `⍋"⌽+"≢⊘⊇"⊕[45)]"2÷Ṅ46)1$5*`, 26 bytes: implicit input takes every number of both lines; radix sort, then `(S + ⌽S)[n/2]` is `S[(n-1)/2] + S[n/2] = s`. It prints s/2: a `-` when s = -1 (where the integer part 0 loses the sign), `s÷2` (truncating), `.`, and `5·(s&1)`. O(n), not O(log(m+n)); reading is O(n) anyway.
Full: `full  golf 0.187s  py 0.183s  OK`
Gaps: no float or fixed-point output: printing x.0 / x.5 the way Python does is 18 of the 26 bytes.
