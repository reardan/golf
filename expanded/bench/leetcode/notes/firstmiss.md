41 First Missing Positive, Hard. Input: the numbers.
Golf `≢ʀ⊕\\‹diff›⍘`, 11 bytes: the candidates `1 … n+1` (`≢ʀ⊕`), less the input with the hash-set `‹diff›` (the `\\` puts the implicit input on top), and `⍘` takes the first one left. O(n) expected.
Full: `full  golf 0.576s  py 1.034s  OK` (1M numbers: 1..n with one gap, plus negatives, large values and repeats).
Gaps: `‹diff›` has no digraph (6 bytes), unlike `ʘ3` union and `ʘi` inter; its operand order needs the `\\`.
