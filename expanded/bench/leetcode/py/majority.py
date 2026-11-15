import sys
cand, cnt = None, 0
for x in map(int, sys.stdin.read().split()):  # Boyer-Moore vote
    if cnt == 0:
        cand = x
    cnt += 1 if x == cand else -1
print(cand)
