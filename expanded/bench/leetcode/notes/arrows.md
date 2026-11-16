452 Minimum Number of Arrows to Burst Balloons, Medium. Input: the balloons as a flat list `s e s e …`.
Golf `2ʘ%Ṁ⍒⟦&Ṁ&Ṃ≺⊕[\\⇡c]_⟧⍀←c⊕`, 23 bytes: the `nonoverlap` scan (sorted by end, switch to the current balloon when `start > end` of the last arrow), with a global counter `⇡c` bumped at each switch; the answer is switches + 1.
Timing: `full  golf 0.190s  py 0.305s  OK` (300k balloons, coordinates up to ±2^31).
Gaps: as `nonoverlap` (no select atom, no counting scan); a block cannot reach a counter threaded under the scan without a rot, hence the global.
