import sys
a = list(map(int, sys.stdin.read().split()))
reach = 0
for i, x in enumerate(a):
    if i > reach:
        break
    reach = max(reach, i + x)
print('true' if reach >= len(a) - 1 else 'false')
