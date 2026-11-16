import sys
s = sys.stdin.readline().rstrip('\n')
t = [c.lower() for c in s if c.isalnum()]
print('true' if t == t[::-1] else 'false')
