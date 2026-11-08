import sys
amount, *coins = map(int, sys.stdin.read().split())
INF = amount + 1
dp = [0] + [INF] * amount
for i in range(1, amount + 1):
    for c in coins:
        if c <= i and dp[i - c] + 1 < dp[i]:
            dp[i] = dp[i - c] + 1
print(dp[amount] if dp[amount] != INF else -1)
