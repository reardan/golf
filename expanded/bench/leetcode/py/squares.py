import sys
from math import isqrt
n = int(sys.stdin.read())
sq = [i * i for i in range(1, isqrt(n) + 1)]
dp = [0] * (n + 1)
for i in range(1, n + 1):
    dp[i] = 1 + min(dp[i - s] for s in sq if s <= i)
print(dp[n])
