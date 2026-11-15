import sys
from functools import reduce
nums = list(map(int, sys.stdin.read().split()))
print(reduce(lambda a, b: a ^ b, nums))
