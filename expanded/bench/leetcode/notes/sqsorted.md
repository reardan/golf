977 Squares of a Sorted Array, Easy. Input: the sorted numbers (500k ints in ±10^6). Output: the squares, sorted, space-separated.
Golf `²⍋`, 2 bytes: `²` squares the implicit input elementwise and `⍋` sorts it; the W15 radix sort is linear, so this matches the two-pointer O(n) of `py/`.
Full: `  full  golf 0.362s  py 0.888s  OK`
Gaps: none.
