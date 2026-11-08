import sys
lo, best = float('inf'), 0
for p in map(int, sys.stdin.read().split()):
    lo = min(lo, p)
    best = max(best, p - lo)
print(best)
