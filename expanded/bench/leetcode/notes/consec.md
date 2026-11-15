**128 Longest Consecutive Sequence** (Medium). Input: the numbers (possibly none), whitespace-separated. Output the length.
Golf `ĊḲ⍋ℑ-"1ʘk∑≡∑±` (13 bytes): `ĊḲ⍋` is the sorted distinct values, `ℑ-` subtracts each one's index, so a run of consecutive values becomes a run of equal ones; `1ʘk∑` is the most common of those (the sum of the one-element list, `0` for the empty input) and `≡∑±` counts how often it occurs.
Full (500k ints in ±500k): `full  golf 0.154s  py 0.281s  OK`.
**Gaps:** no "largest count" word: `Ċ‹vals›Ṁ` costs 8 bytes and fails on the empty input (`Ṁ` of `[]` is `empty reduce`), hence the `ʘk` detour; no one-byte unique (`ĊḲ` stands in, `‹unique›` is 8 bytes).
