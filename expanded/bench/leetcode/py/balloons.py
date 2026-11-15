import sys
a = [1] + list(map(int, sys.stdin.read().split())) + [1]
m = len(a)
dp = [[0] * m for _ in range(m)]
for L in range(2, m):
    for l in range(m - L):
        r = l + L; al = a[l] * a[r]; row = dp[l]
        dp[l][r] = max(row[k] + dp[k][r] + al * a[k] for k in range(l + 1, r))
print(dp[0][m - 1])
