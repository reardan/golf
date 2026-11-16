import sys
h = list(map(int, sys.stdin.read().split()))
i, j, best = 0, len(h) - 1, 0
while i < j:
    if h[i] < h[j]:
        best = max(best, h[i] * (j - i)); i += 1
    else:
        best = max(best, h[j] * (j - i)); j -= 1
print(best)
