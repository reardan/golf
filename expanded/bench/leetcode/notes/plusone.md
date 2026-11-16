66 Plus One, Easy. Input: the digits, space-separated. Output: the digits of the number plus one.
Golf `⌽0⍆"9⌊⍃9/+10%"ʘ$⊖↓⌽`, 19 bytes: reverse and append a 0 (room for the carry), `9⌊⍃` is the exclusive running min of the digits seeded with 9, so it is 9 exactly where every less significant digit is 9 (the carry), `9/+` adds that carry, `10%` wraps 10 to 0; `"ʘ$⊖↓` drops the extra top digit when it stayed 0 (`↓` of -1), and `⌽` turns it back.
`full  golf 0.255s  py 0.263s  OK` (1M digits, the last third all 9).
Gaps: no right-to-left exclusive scan (`⍂` is inclusive), so the carry costs two `⌽`; no "drop a leading 0" / conditional prepend, so the carry digit costs `0⍆` plus `"ʘ$⊖↓` (7 bytes in all).
