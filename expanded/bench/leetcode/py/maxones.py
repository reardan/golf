import sys
best = run = 0
for x in map(int, sys.stdin.read().split()):
    run = run + 1 if x == 1 else 0
    best = max(best, run)
print(best)
