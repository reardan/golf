58 Length of Last Word, Easy. Input: one line of letters and spaces (leading/trailing spaces allowed).
Golf `ʘW⍅≢`, 4 bytes: `‹words›` splits the line (implicit input, a text line), `⍅` pops the last word off the word list, `≢` is its length; the word list left under it is not printed (implicit output prints the top when nothing was written).
`full  golf 0.404s  py 0.111s  OK` (a 10M-character line).
Gaps: none for size; it is slower than Python because `ʘW` builds every word as a list (about 1.4M of them) to keep only the last one.
