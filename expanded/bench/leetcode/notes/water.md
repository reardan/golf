11 Container With Most Water, Medium. Input: the heights (1M, 0…10^4).
Golf `ʘV"⌈⍂\\⌊⍂-①⍋*Ṁ`, 13 bytes: not two pointers but the sorted order. `o = ‹grade›` (ascending); every bar at or after sorted position i is at least as tall as `sorted[i]`, and the widest pair among them spans `max(o[i:]) - min(o[i:])` (suffix max and min, `⌈⍂ ⌊⍂`), so the answer is max of `sorted[i] * span[i]` (`①⍋` is the sorted heights). O(n) with the radix sort.
Full: `full  golf 0.263s  py 0.282s  OK`
Gaps: none (implicit input only fires on an empty stack, so the second copy of the input is `①`, 1 byte more than an implicit pop).
