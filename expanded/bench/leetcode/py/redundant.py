import sys
n, *e = map(int, sys.stdin.read().split())
p = list(range(n + 1))
def find(x):
    while p[x] != x:
        p[x] = p[p[x]]
        x = p[x]
    return x
for i in range(0, len(e), 2):
    a, b = find(e[i]), find(e[i + 1])
    if a == b:
        print(e[i], e[i + 1])
        break
    p[a] = b
