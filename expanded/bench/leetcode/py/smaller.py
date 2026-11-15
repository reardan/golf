import sys
a = list(map(int, sys.stdin.read().split()))
rank = {v: i + 1 for i, v in enumerate(sorted(set(a)))}
n = len(rank); tree = [0] * (n + 1); out = []
for x in reversed(a):
    r = rank[x]; i = r - 1; c = 0
    while i > 0:
        c += tree[i]; i -= i & -i
    out.append(c)
    while r <= n:
        tree[r] += 1; r += r & -r
print(' '.join(map(str, reversed(out))))
