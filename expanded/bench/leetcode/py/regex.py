import sys
s, p = sys.stdin.read().split('\n')[:2]
n, m = len(s), len(p)
# dp[j] = s[i:] matches p[j:], filled from i = n down to 0
nxt = [False] * (m + 1); nxt[m] = True
for j in range(m - 1, -1, -1):
    if j + 1 < m and p[j + 1] == '*': nxt[j] = nxt[j + 2]
for i in range(n - 1, -1, -1):
    cur = [False] * (m + 1)
    for j in range(m - 1, -1, -1):
        first = p[j] == s[i] or p[j] == '.'
        if j + 1 < m and p[j + 1] == '*':
            cur[j] = cur[j + 2] or (first and nxt[j])
        else:
            cur[j] = first and nxt[j + 1]
    nxt = cur
print('true' if nxt[0] else 'false')
