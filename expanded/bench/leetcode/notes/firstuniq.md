387 First Unique Character in a String, Easy. Input: the string (lowercase letters) on one line.
Golf `Ṕ⥮⌈⊕⍷`, 5 bytes: `Ṕ⥮` is "previous occurrence" both ways (from the left, and from the right reversed back), so a letter is unique exactly when both are `-1`; `⌈` keeps the larger, which is `-1` only then, and `⊕⍷` finds the first index where `x+1` is `0` (`-1` when none).
`full  golf 0.146s  py 0.144s  OK` (2M letters, the one unique letter in the last tenth).
Gaps: none.
