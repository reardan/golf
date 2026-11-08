import sys
t, *a = map(int, sys.stdin.read().split())
seen = {}
for i, x in enumerate(a):
    if t - x in seen:
        print(seen[t - x], i)
        break
    seen[x] = i
