import sys
d = list(map(int, sys.stdin.read().split()))
i = len(d) - 1
while i >= 0 and d[i] == 9:
    d[i] = 0
    i -= 1
if i < 0:
    d.insert(0, 1)
else:
    d[i] += 1
print(' '.join(map(str, d)))
