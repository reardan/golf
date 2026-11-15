import sys
a = list(map(int, sys.stdin.read().split()))
jumps = end = far = 0
for i in range(len(a) - 1):
    far = max(far, i + a[i])
    if i == end:
        jumps += 1
        end = far
print(jumps)
