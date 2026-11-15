import sys
from collections import Counter
s = sys.stdin.readline().strip()
c = Counter(s)
print(next((i for i, ch in enumerate(s) if c[ch] == 1), -1))
