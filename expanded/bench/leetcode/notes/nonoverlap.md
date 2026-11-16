435 Non-overlapping Intervals, Medium. Input: the intervals as a flat list `s e s e …`.
Golf `2ʘ%Ṁ⍒"⟦&Ṁ&Ṃ≻[\\]_⟧⍀﹣⊞ʘ?≢`, 23 bytes: pairs (`2ʘ%`), sorted by end (`Ṁ` of a pair is its end, `Ṃ` its start), then a scan that keeps the last kept interval and switches to the current one when `start >= end` of the kept one; the removed intervals are the positions where the scan result is not the interval itself (`﹣⊞` compares the list cells raw, `ʘ?≢` counts the non-zero).
Timing: `full  golf 0.162s  py 0.231s  OK` (300k intervals).
Gaps: no select (`c a b -> a|b`) atom: `[\\]_` spells it; no greedy "scan with state + count" word; `≡` on lists of lists maps into the elements, so cell identity needs the raw `﹣⊞`.
