409 Longest Palindrome, Easy. Input: the string (upper and lower case letters) on one line.
Golf `≢\\⍋-⍙1↓≢-`, 9 bytes: `≢\\` keeps `n` under the letters, `⍋-⍙` sorts them and cancels equal neighbours in pairs (stack cancel with `-`), leaving one of each letter that occurs an odd number of times; all but one of those must go (`1↓≢`), and `-` takes that from `n`.
`full  golf 0.252s  py 0.183s  OK` (5M letters). (`≢\\1\\≪⊞=⍁♯⊖0⌈-`, the XOR of `1≪c` and its popcount, is 13.)
Gaps: none. `≪` does not map over lists (the bit atoms `$ | = ≪ ≫` stay raw), so the bitmask version needed `⊞`.
