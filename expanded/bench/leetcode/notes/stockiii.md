123 Best Time to Buy and Sell Stock III, Hard. Input: the prices.
Golf `⌊⍀-⌈⍀\\"⌈⍂-⌊⍂-Ṁ`, 14 bytes. `⌊⍀-⌈⍀` is L, the best single trade within days 0 … i (Stock I's running form); `\\"` brings the prices back up twice; `⌈⍂-⌊⍂` is minus R, the best single trade within days i … n-1 (price minus the highest price after it, its running minimum from the right). The answer is the largest L - (-R). O(n).
Full: `full  golf 0.152s  py 0.350s  OK` (1M prices up to 10^5).
Gaps: none (`⥮` cannot do both halves, since the left half wants a running minimum and the right a running maximum).
