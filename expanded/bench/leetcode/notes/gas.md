**134 Gas Station** (Medium). Input: `gas` on line 1, `cost` on line 2. Output the start index or `-1`.
Golf `≢⊘ʘ%-⍁"0+⍃ʘ0\\∑0≺|` (17 bytes): `≢⊘ʘ%-⍁` splits the input into its two halves and subtracts them (`d = gas - cost`); the start is the first minimum (`ʘ0`) of the exclusive prefix sums `0+⍃`, and `∑0≺|` ORs in `-1` when the total is negative.
Full (1M stations): `full  golf 0.181s  py 0.448s  OK`.
**Gaps:** `①②-` (3 bytes) would read the two lines, but `①` types a one-token line as an int, not a one-element list, so n = 1 (`5` / `4`) breaks the list ops after it: `printf '5\n4\n' | ./p` with `①②-"0+⍃` fails. Halving the implicit input costs 6 bytes instead.
