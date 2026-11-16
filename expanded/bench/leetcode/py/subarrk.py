import sys
from collections import defaultdict
k, *nums = map(int, sys.stdin.read().split())
seen = defaultdict(int); seen[0] = 1
s = count = 0
for x in nums:
    s += x
    count += seen[s - k]
    seen[s] += 1
print(count)
