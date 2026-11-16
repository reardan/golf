64 Minimum Path Sum, Medium. Input: `m n`, then the grid, one row per line.
Golf `⍘_⍘ʘ%+⍀€⍘⟦\\&0⌈⍃-⌊⍀+⟧⇤ʘ$`, 23 bytes: `⍘_⍘ʘ%` cuts the values into rows and `+⍀€` turns each into its prefix sums B (the first is dp of row 0). A row step is the min-plus scan `new = B + ⌊⍀(dp − Bx)`, Bx being B shifted right (`0⌈⍃`, valid since B never decreases); `ʘ$` takes the last cell.
Full: `full  golf 0.138s  py 0.344s  OK` (1000 × 1003 grid, values 0–200).
Gaps: an int grid needs a size header and `⍘_⍘ʘ%` (5 bytes); no rot, so a value needed twice in a fold step has to be precomputed (`+⍀€`) or go through a global; no shift-right word (`0⌈⍃` only works on non-decreasing rows).
