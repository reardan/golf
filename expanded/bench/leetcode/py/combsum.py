import sys
target, *cands = map(int, sys.stdin.read().split())
dp = [1] + [0] * target
for c in cands:
    for s in range(c, target + 1):
        dp[s] += dp[s - c]
print(dp[target])
