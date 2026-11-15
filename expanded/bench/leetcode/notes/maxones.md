485 Max Consecutive Ones, Easy. Input: the 0/1 array.
Golf `⟦\\⊕*⟧⍀Ṁ`, 7 bytes: a scan whose step is `x*(acc+1)` (the run length ending here, reset by a 0), then the largest.
Timing: `full  golf 0.128s  py 0.327s  OK` (2M values).
Gaps: no "run length / reset scan" idiom; the step needs a swap (`\\⊕*`) and so a 2-byte block.
