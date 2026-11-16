import sys
s = sys.stdin.read().strip()
val = {'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100, 'D': 500, 'M': 1000}
total = 0
for a, b in zip(s, s[1:]):
    v = val[a]
    total += -v if v < val[b] else v
print(total + val[s[-1]])
