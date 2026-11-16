import sys
m, n, *v = map(int, sys.stdin.read().split())
g = [v[i * n:(i + 1) * n] for i in range(m)]
dp = [0] * n
for i in range(m):
    for j in range(n):
        if i == 0 and j == 0:
            dp[j] = g[0][0]
        elif i == 0:
            dp[j] = dp[j - 1] + g[i][j]
        elif j == 0:
            dp[j] += g[i][j]
        else:
            dp[j] = min(dp[j], dp[j - 1]) + g[i][j]
print(dp[-1])
