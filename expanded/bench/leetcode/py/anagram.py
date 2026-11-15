import sys
from collections import Counter
s, t = (sys.stdin.read().split('\n') + ['', ''])[:2]
print('true' if Counter(s) == Counter(t) else 'false')
