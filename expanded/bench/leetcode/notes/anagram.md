**242 Valid Anagram** (Easy). Input: `s` on line 1, `t` on line 2 (lowercase letters). Output `true`/`false`.
Golf `⍋②⍋≣⊕ṭ` (6 bytes): implicit input is line 1 as a code list, `⍋` sorts it, `②⍋` sorts line 2, `≣` compares the two (`-1` equal), `⊕ṭ` prints it.
Full (two 2M-letter strings, an anagram): `full  golf 0.262s  py 0.157s  OK`.
**Gaps:** none in bytes; the radix sort of 2M codes is slower than Python's `Counter`, and there is no "same multiset" word (comparing two `Ċ` dicts with `≣` depends on insertion order).
