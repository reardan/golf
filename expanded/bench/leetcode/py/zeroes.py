import sys
nums = list(map(int, sys.stdin.read().split()))
j = 0
for i in range(len(nums)):
    if nums[i] != 0:
        nums[i], nums[j] = nums[j], nums[i]
        j += 1
print(*nums)
