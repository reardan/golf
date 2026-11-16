import sys
from collections import defaultdict, deque
begin, end, *words = sys.stdin.read().split()
if end not in words:
    print(0)
    sys.exit()
L = len(begin)
groups = defaultdict(list)              # 'h*t' -> words that match it
for w in set(words):
    for i in range(L):
        groups[w[:i] + '*' + w[i + 1:]].append(w)
dist = {begin: 1}
q = deque([begin])
while q:
    w = q.popleft()
    if w == end:
        print(dist[w])
        sys.exit()
    for i in range(L):
        for v in groups.pop(w[:i] + '*' + w[i + 1:], ()):
            if v not in dist:
                dist[v] = dist[w] + 1
                q.append(v)
print(0)
