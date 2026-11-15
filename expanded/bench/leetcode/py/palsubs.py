import sys
s = sys.stdin.readline().rstrip('\n')
n, c = len(s), 0
for m in range(2 * n - 1):   # expand around each of the 2n-1 centres
    i, j = m // 2, (m + 1) // 2
    while i >= 0 and j < n and s[i] == s[j]:
        c += 1; i -= 1; j += 1
print(c)
