import sys
s, t = sys.stdin.read().split('\n')[:2]
m = len(t)
dp = [1] + [0] * m
for c in s:
    for j in range(m, 0, -1):
        if t[j - 1] == c:
            dp[j] += dp[j - 1]
print(dp[m])
