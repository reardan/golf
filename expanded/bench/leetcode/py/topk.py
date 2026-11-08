import sys
from collections import Counter
k, *a = map(int, sys.stdin.read().split())
c = Counter(a)
print(*sorted(c, key=lambda v: (-c[v], v))[:k])
