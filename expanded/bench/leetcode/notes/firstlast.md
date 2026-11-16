34 Find First and Last Position of Element in Sorted Array, Medium. Input: target, then the sorted array (1M, values ±10^5, so long runs); may be empty.
Golf `⍘≡"⊕⍷Ṅ32)ʘ?1±⍆Ṁ`, 15 bytes: first = `⊕⍷` (as in rotsearch, -1 if absent), printed with `Ṅ` and a space; last = the largest match position (`ʘ?` = where), with `-1` pushed so that no match gives -1. O(n).
Full: `full  golf 0.123s  py 0.153s  OK`
Gaps: two numbers cannot be left for implicit output (it prints only the top) and there is no pair constructor, so `Ṅ32)` (4 bytes); `Ṁ`/`Ṃ` throw on an empty list (no max-or-default), hence `1±⍆`.
