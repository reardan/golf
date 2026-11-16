import sys
target, *nums = map(int, sys.stdin.read().split())
total = sum(nums)
if abs(target) > total or (total + target) % 2:
    print(0)
else:
    p = (total + target) // 2       # subsets summing to p get the + sign
    dp = [1] + [0] * p
    for x in nums:
        for s in range(p, x - 1, -1):
            dp[s] += dp[s - x]
    print(dp[p])
