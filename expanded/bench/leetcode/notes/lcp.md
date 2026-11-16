14 Longest Common Prefix, Easy. Input: one string per line, each non-empty lowercase letters (200k strings, the answer 39 letters).
Golf `⎕ʘW⟦&≡⌈⍀∑±↑⟧⍁⊐`, 14 bytes: reduce the words with "common prefix of two": `≡` compares to the shorter length, `⌈⍀` keeps `-1` only while all so far matched, `-∑` is the prefix length, `↑` cuts the first word to it.
Full: `full  golf 0.782s  py 1.197s  OK`
Gaps: `‹words›` drops empty lines, so LeetCode's empty string `""` cannot be an input (the format excludes it; `⎕10‹split›` keeps them but adds a trailing empty field, about +8 bytes); its words carry no text mark, so the answer needs `⊐`; no mismatch-index / common-prefix word (`&≡⌈⍀∑±`, 6 bytes).
