import sys
from bisect import bisect_left
target, *nums = map(int, sys.stdin.read().split())
i = bisect_left(nums, target)
print(i if i < len(nums) and nums[i] == target else -1)
