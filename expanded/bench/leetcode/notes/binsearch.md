704 Binary Search, Easy. Input: target, then the sorted array.
Golf `⍘-±⍷`, 4 bytes: `⍘` splits off the target, `-` subtracts it from every element, `⍷` with `±` finds the first zero, `-1` if none.
It is a linear scan (O(n), the same as reading the input) rather than a binary search: `ʘb` (lower bound) needs a second test that the element is the target, which costs more bytes.
Timing: `full  golf 0.102s  py 0.154s  OK` (1M sorted ints).
Gaps: no "index of x in a sorted list, else -1" word (`ʘb` gives the insertion point only); `‹indexof›` is 9 bytes.
