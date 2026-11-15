import sys
from collections import Counter
lines = sys.stdin.read().split('\n')
s, t = lines[0], lines[1]
need = Counter(t)
missing = len(t)
l = 0
bl, br = 0, -1
for r, ch in enumerate(s):
    if need[ch] > 0:
        missing -= 1
    need[ch] -= 1
    if missing == 0:
        while need[s[l]] < 0:
            need[s[l]] += 1
            l += 1
        if br < 0 or r - l < br - bl:
            bl, br = l, r
        need[s[l]] += 1
        missing += 1
        l += 1
print(s[bl:br + 1])
