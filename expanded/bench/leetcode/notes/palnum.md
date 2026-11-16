9 Palindrome Number, Easy. Input: one integer (the large input is a 9-digit palindrome; the problem has no large size).
Golf `ℓʘ4ṭ`, 4 bytes: `ℓ` reads the line raw as text (implicit input would read a leading `-` or digit as a number), `‹ispal›` (`ʘ4`) tests that it reads the same backwards (a `-` sign never does), `ṭ` gives `true`/`false`.
Full: `full  golf 0.004s  py 0.016s  OK`
Gaps: none.
