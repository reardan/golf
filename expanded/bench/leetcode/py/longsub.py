import sys
s = sys.stdin.read().strip()
last, start, best = {}, 0, 0
for i, c in enumerate(s):
    if last.get(c, -1) >= start:
        start = last[c] + 1
    last[c] = i
    best = max(best, i - start + 1)
print(best)
