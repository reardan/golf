354 Russian Doll Envelopes, Hard. Input: the envelopes as a flat list `w h w h …`.
Golf `2ʘ%ʘ$⍖⍘⍒ʘ$€"Ṁ⊕-ℑ⟦&&ʘb\\⍈⟧⇤0ʘb`, 28 bytes: sort by height descending, then (stably) by width (`⍘` as a key leaves the pair's tail under each key; `€` threading keeps that junk out of the way), take the heights shifted below 0 (`"Ṁ⊕-`), and run patience LIS: tails start as `0 … n-1` (all above every height), each height overwrites `tails[bisect]` in place; the length is the number of negative tails (`0ʘb`). O(n log n).
Timing: `full  golf 0.337s  py 0.484s  OK` (300k envelopes).
Gaps: no LIS word and no "bisect then append-or-replace"; no key for sorting by two fields, so two stable sorts.
