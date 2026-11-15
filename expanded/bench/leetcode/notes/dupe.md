**217 Contains Duplicate** (Easy). Input: the numbers, whitespace-separated. Output `true`/`false`.
Golf `Ḍ⊕ṭ` (3 bytes): `Ḍ` (all distinct) gives `0` when no two are equal and `-1` otherwise; `⊕` turns that into `1`/`0`, and `ṭ` prints `0` as `true`.
Full (1M distinct ints, answer false): `full  golf 0.333s  py 0.312s  OK`.
**Gaps:** none (the `⊕` is only there because `Ḍ` answers "distinct", not "has a duplicate").
