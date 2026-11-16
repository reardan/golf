69 Sqrt(x), Easy. Input: x.
Golf `∑‹isqrt›`, 8 bytes: `∑` turns the one-number input list into `x`, and the prelude's exact integer square root does the rest.
Full: `full  golf 0.005s  py 0.015s  OK` (one x below 2^31; the size does not matter here).
Gaps: `‹isqrt›` has no digraph or byte, so 6 of the 8 bytes are its name (a `‹bsearch›` on `r² > x` is longer, 11 bytes).
