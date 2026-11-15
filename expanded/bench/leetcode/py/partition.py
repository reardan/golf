import sys
a = list(map(int, sys.stdin.read().split()))
s = sum(a)
if s % 2:
    print('false')
else:
    t = s // 2
    dp = [True] + [False] * t
    for x in a:
        for j in range(t, x - 1, -1):
            if dp[j - x]:
                dp[j] = True
    print('true' if dp[t] else 'false')
