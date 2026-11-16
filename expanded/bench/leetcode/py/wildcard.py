import sys
lines = sys.stdin.read().split('\n')
s, p = lines[0], lines[1] if len(lines) > 1 else ''
dp = [True] + [False] * len(s)   # dp[j]: p[:i] matches s[:j]
for c in p:
    if c == '*':
        for j in range(1, len(s) + 1):
            dp[j] = dp[j] or dp[j - 1]
    else:
        for j in range(len(s), 0, -1):
            dp[j] = dp[j - 1] and (c == '?' or c == s[j - 1])
        dp[0] = False
print('true' if dp[-1] else 'false')
