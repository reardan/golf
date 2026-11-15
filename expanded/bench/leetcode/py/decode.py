import sys
s = sys.stdin.readline().strip()
a, b = 0, 1   # ways for s[:i-1], s[:i]
for i, c in enumerate(s):
    one = b if c != '0' else 0
    two = a if i > 0 and 10 <= int(s[i - 1:i + 1]) <= 26 else 0
    a, b = b, one + two
print(b)
