26 Remove Duplicates from Sorted Array, Easy. Input: the sorted numbers. Output: k, the number of distinct values.
Golf `ĊḲ≢`, 3 bytes: `Ċ` counts the input into a dict, `Ḳ` lists its keys, `≢` counts them (it never uses the sort: O(n) expected).
`full  golf 0.251s  py 0.296s  OK` (1M sorted ints in ±10^6).
Gaps: none (a 2-byte "count distinct" or "unique" alias would make it 2; `‹unique›≢` is 10).
