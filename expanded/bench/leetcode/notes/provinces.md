547 Number of Provinces, Medium. Input: the n × n adjacency matrix as a digit grid, one row per line, no spaces (n = 2000). Output: the count.
Golf `⎕ʘW2%ʘ?€‹comps›Ṁ⊕`, 17 bytes: `⎕ʘW` splits the rows, `2%` maps `'1'` to 1 and `'0'` to 0 (it maps to any depth), `ʘ?€` turns each row into the indices of its 1s, which is the adjacency list, and `‹comps›` labels the components; the count is the largest label plus one. O(n²).
Full: `  full  golf 0.198s  py 0.286s  OK`
Gaps: `‹comps›` has no digraph (7 bytes). A matrix row of digits cannot come in through `①`/implicit input (`0110` reads as the number 110), hence `⎕ʘW`.
