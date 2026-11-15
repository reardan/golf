import sys
strs = sys.stdin.read().split('\n')[:-1]
p = strs[0]
for s in strs[1:]:
    i = 0
    while i < len(p) and i < len(s) and p[i] == s[i]:
        i += 1
    p = p[:i]
print(p)
