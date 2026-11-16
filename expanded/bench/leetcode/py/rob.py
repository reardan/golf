import sys
a = b = 0
for x in map(int, sys.stdin.read().split()):
    a, b = b, max(b, a + x)
print(b)
