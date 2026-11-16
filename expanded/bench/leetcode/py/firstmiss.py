import sys
a = list(map(int, sys.stdin.read().split()))
n = len(a)
for i in range(n):  # cyclic sort: put v at index v-1
    while 1 <= a[i] <= n and a[a[i] - 1] != a[i]:
        j = a[i] - 1
        a[i], a[j] = a[j], a[i]
for i in range(n):
    if a[i] != i + 1:
        print(i + 1)
        break
else:
    print(n + 1)
