33 Search in Rotated Sorted Array, Medium. Input: target, then the distinct rotated array (1M).
Golf `⍘≡⊕⍷`, 4 bytes: `⍘` splits off the target, `≡` flags the equal element, `⊕⍷` is the first index whose flag+1 is 0, or -1.
Full: `full  golf 0.121s  py 0.152s  OK`
A linear scan, not LeetCode's O(log n) search: reading the input is O(n) already, and both run in the same time.
Gaps: none.
