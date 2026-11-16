import sys
n = int(sys.stdin.read())
G = [1] + [0] * n
for k in range(1, n + 1):
    G[k] = sum(G[i] * G[k - 1 - i] for i in range(k))
print(G[n])
