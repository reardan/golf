309 Best Time to Buy and Sell Stock with Cooldown, Medium. Input: the prices.
Golf `⊡f⇒x⇒s⇒bs\\x-b⌈sbx+⌈;0ℤ⍘±\\0f⇤`, 28 bytes: the three-state DP (`q` = sold two days ago, `b` = holding, `s` = sold). `⇤`'s step keeps `q b` threaded under the accumulator `s` and maps `q b s x` to `s, max(b, q-x), max(s, b+x)`; the first day is taken out with `⍘±` to start `b` at `-p0`, and the final `s` is on top. O(n).
`full  golf 0.076s  py 0.326s  OK` (1M prices up to 1000).
Gaps: a fold has one accumulator, so a 3-value state needs a `⊡` word with three locals and two values threaded under the list; the list must then be read with `ℤ`, since implicit input only arrives on an empty stack. A tuple-state fold/scan (or a stack rotate) would remove most of it.
