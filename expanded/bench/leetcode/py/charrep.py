import sys
k = int(sys.stdin.readline()); s = sys.stdin.readline().strip()
cnt = {}; maxf = 0; l = 0
for r, ch in enumerate(s):
    cnt[ch] = cnt.get(ch, 0) + 1
    maxf = max(maxf, cnt[ch])
    if r - l + 1 - maxf > k:
        cnt[s[l]] -= 1; l += 1
print(len(s) - l)
