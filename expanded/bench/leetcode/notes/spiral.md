54 Spiral Matrix, Medium. Input: the m×n grid, one row per line. Output: the spiral order, space-separated.
Golf `"ℓʘW≢ʘ%{⍘⍕ʘz⌽"≢0≡}`, 18 bytes: rows as in `rotate` (`"ℓʘW≢ʘ%`), then a loop that prints the first row (`⍘⍕`), turns the rest a quarter counter-clockwise (`ʘz⌽`, transpose then reverse the rows) and repeats while rows are left (`"≢0≡`).
`full  golf 1.114s  py 0.101s  OK` (500×400; 646 MB peak).
Gaps: no spiral/ring word, so the short form is the peel-and-rotate idiom, O(mn(m+n)) and leaking every rotated copy (11× slower than Python, 646 MB); "loop while non-empty" costs `"≢0≡` (no not-empty test that gives 0); the grid-reading gap of `rotate` (`"ℓʘW≢ʘ%`; `①≢` fails on one column).
