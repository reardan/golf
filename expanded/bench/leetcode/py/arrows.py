import sys
a = list(map(int, sys.stdin.read().split()))
pts = sorted(zip(a[::2], a[1::2]), key=lambda p: p[1])
end, arrows = None, 0
for s, e in pts:
    if end is None or s > end:
        end, arrows = e, arrows + 1
print(arrows)
