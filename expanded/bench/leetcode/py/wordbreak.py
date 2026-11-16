import sys
lines = sys.stdin.read().split('\n')
s, words = lines[0], set(lines[1].split())
lens = sorted({len(w) for w in words})
n = len(s)
dp = [False] * (n + 1)
dp[0] = True
for i in range(1, n + 1):
    for L in lens:
        if L > i:
            break
        if dp[i - L] and s[i - L:i] in words:
            dp[i] = True
            break
print('true' if dp[n] else 'false')
