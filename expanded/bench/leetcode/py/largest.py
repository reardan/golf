import sys
from functools import cmp_to_key
s = sys.stdin.read().split()
s.sort(key=cmp_to_key(lambda a, b: (a + b < b + a) - (a + b > b + a)))
r = ''.join(s)
print('0' if r[0] == '0' else r)
