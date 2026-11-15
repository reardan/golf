import sys
nums = list(map(int, sys.stdin.read().split()))
k = 0
for x in nums:
    if k == 0 or nums[k - 1] != x:
        nums[k] = x
        k += 1
print(k)
