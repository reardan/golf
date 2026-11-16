import sys
from collections import Counter
s = sys.stdin.readline().strip()
odd = sum(v & 1 for v in Counter(s).values())
print(len(s) - odd + (odd > 0))
