import sys
nums = list(map(int, sys.stdin.read().split()))
n = len(nums)
print(n * (n + 1) // 2 - sum(nums))
