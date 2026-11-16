import sys
k, *nums = map(int, sys.stdin.read().split())
nums.sort()
print(nums[-k])
