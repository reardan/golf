23 Merge k Sorted Lists, Hard. Input: one sorted list per line (an empty line is an empty list; no lines is k = 0). Output: the merged list.
Golf `⍋`, 1 byte: implicit input reads every number of every line as one list, and `⍋` (LSD radix sort, linear) sorts it; Python's reference is `heapq.merge`.
`full  golf 0.125s  py 0.259s  OK` (k = 1000 lists, 300k numbers in ±10^4).
Gaps: none.
