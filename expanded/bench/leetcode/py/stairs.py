import sys
n = int(sys.stdin.read())
a, b = 1, 1
for _ in range(n):
    a, b = b, a + b
print(a)
