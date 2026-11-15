169 Majority Element, Easy. Input: the numbers (one value occurs more than n/2 times).
Golf `1ʘk`, 3 bytes: `‹mostcommon›` with k = 1 on the implicit input; the one-element list prints as the answer.
Full: `full  golf 0.235s  py 0.186s  OK` (1M numbers, ~500k distinct); the 5-byte `⍋"≢⊘⊇` (sort, take the middle) runs in about 0.14 s.
Gaps: none in bytes; `‹mostcommon›` on half a million distinct values is slower than Python's Boyer-Moore loop.
