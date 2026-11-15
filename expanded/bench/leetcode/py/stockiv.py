import sys
k, *p = map(int, sys.stdin.read().split())
buy = [-10**18] * (k + 1); sell = [0] * (k + 1)
for x in p:
    for j in range(1, k + 1):
        buy[j] = max(buy[j], sell[j - 1] - x)
        sell[j] = max(sell[j], buy[j] + x)
print(sell[k])
