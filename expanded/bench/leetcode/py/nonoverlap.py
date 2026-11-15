import sys
a = list(map(int, sys.stdin.read().split()))
iv = sorted(zip(a[::2], a[1::2]), key=lambda p: p[1])
end, kept = float('-inf'), 0
for s, e in iv:
    if s >= end:
        end, kept = e, kept + 1
print(len(iv) - kept)
