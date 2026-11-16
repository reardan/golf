560 Subarray Sum Equals K, Medium. Input: k, then the nums.
Golf `+⍀Ḋ\\⟦&&Ḃ_①-&\\0Ǧ①0≡+⟧€∑`, 22 bytes: `+⍀` of the whole input is `k + prefix sums` (with the leading 0 as `k` itself), mapped with a dict threaded under `€`: bump the prefix, then look up `prefix - k` (`①` is `k`); because the bump must come first (the lookup consumes the dict and there is no rot), the prefix counts itself when `k = 0`, which `①0≡+` takes off.
Timing: `full  golf 0.242s  py 0.245s  OK` (1M nums).
Gaps: no rot / no "lookup without consuming the dict" (Ǧ eats `d`), which forces bump-before-lookup and the 4-byte `k = 0` correction.
