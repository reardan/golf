import sys
a = list(map(int, sys.stdin.read().split()))
out = []
for s, e in sorted(zip(a[::2], a[1::2])):
    if out and s <= out[-1][1]:
        out[-1][1] = max(out[-1][1], e)
    else:
        out.append([s, e])
print(' '.join(f'{s} {e}' for s, e in out))
