125 Valid Palindrome, Easy. Input: one line of printable ASCII (a 2.9 MB palindrome with random case and punctuation; edge cases include `0P` and lines that start with a digit). Output: `true`/`false`.
Golf `ℓ32|⊞‹isalnum›⌿ʘ4ṭ`, 18 bytes: `ℓ` reads the line raw, `32|⊞` lower-cases letters (bit 5 is already set on digits, and no punctuation becomes alphanumeric), `‹isalnum›⌿` keeps the letters and digits, `ʘ4` (`‹ispal›`) and `ṭ` answer.
Full: `  full  golf 0.214s  py 0.392s  OK`
Gaps: `‹isalnum›` has no byte or digraph (9 of the 18 bytes; `‹lower›` would be 7 more, `32|⊞` is the workaround). `|` does not map over a list, so it needs `⊞`'s broadcast. `ℓ` is required because a line starting with a digit reads as numbers under implicit input.
