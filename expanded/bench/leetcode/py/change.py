import sys
amount, *coins = map(int, sys.stdin.read().split())
dp = [1] + [0] * amount
for c in coins:
    for a in range(c, amount + 1):
        dp[a] += dp[a - c]
print(dp[amount])
