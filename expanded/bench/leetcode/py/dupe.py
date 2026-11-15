import sys
nums = list(map(int, sys.stdin.read().split()))
print('true' if len(set(nums)) < len(nums) else 'false')
