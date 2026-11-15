import sys
target, *nums = map(int, sys.stdin.read().split())
best, s, i = len(nums) + 1, 0, 0
for j, x in enumerate(nums):
    s += x
    while s >= target:
        best = min(best, j - i + 1)
        s -= nums[i]
        i += 1
print(0 if best > len(nums) else best)
