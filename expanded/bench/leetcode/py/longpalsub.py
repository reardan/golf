import sys
s = sys.stdin.readline().rstrip('\n')
n, bi, bl = len(s), 0, 0
for m in range(2 * n - 1):   # expand around each centre; a tie keeps the leftmost
    i, j = m // 2, (m + 1) // 2
    while i >= 0 and j < n and s[i] == s[j]:
        i -= 1; j += 1
    if j - i - 1 > bl:
        bi, bl = i + 1, j - i - 1
print(s[bi:bi + bl])
