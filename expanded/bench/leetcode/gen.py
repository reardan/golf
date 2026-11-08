import os, random, sys
# gen.py SCALE : writes in/<name>.txt ; SCALE 1 = full size
S = float(sys.argv[1]) if len(sys.argv) > 1 else 1
d = sys.argv[2] if len(sys.argv) > 2 else 'in'
os.makedirs(d, exist_ok=True)
R = random.Random(42)
def w(name, s):
    open(f'{d}/{name}.txt', 'w').write(s)
def n(x): return max(4, int(x * S))
N = n(200000); a = R.sample(range(-10**9, 10**9), N)
w('twosum', f'{a[-2]+a[-1]}\n' + ' '.join(map(str, a)) + '\n')
# random valid nesting
L = n(2000000) // 2; st = []; out = []; op = 0
pairs = {'(': ')', '[': ']', '{': '}'}
while op < L or st:
    if op < L and (not st or R.random() < 0.5):
        c = R.choice('([{'); st.append(pairs[c]); out.append(c); op += 1
    else:
        out.append(st.pop())
w('parens', ''.join(out) + '\n')
w('stock', ' '.join(str(R.randint(0, 10**4)) for _ in range(n(1000000))) + '\n')
w('longsub', ''.join(R.choice('abcdefghijklmnopqrstuvwxyz') for _ in range(n(2000000))) + '\n')
w('prodself', ' '.join(R.choice(['1', '-1']) for _ in range(n(1000000))) + '\n')
M = n(1000000)
w('topk', '10\n' + ' '.join(str(int(R.paretovariate(1.2)) % 10000) for _ in range(M)) + '\n')
side = max(4, int(1000 * S ** 0.5))
w('islands', ''.join(''.join(R.choice('01') for _ in range(side)) + '\n' for _ in range(side)))
w('trap', ' '.join(str(R.randint(0, 10**4)) for _ in range(n(1000000))) + '\n')
w('slidemax', f'{min(1000, n(1000000)//2)}\n' + ' '.join(str(R.randint(-10**4, 10**4)) for _ in range(n(1000000))) + '\n')
w('queens', '12\n' if S >= 1 else '8\n')
# --- W13-F: ten more problems (appended, so the ten inputs above stay the same).
# name2.txt, name3.txt, ... are small edge cases, written at every scale; the
# gate runs them too, bench.sh only name.txt.
from collections import deque
N = n(1000000); a = sorted(R.sample(range(-10**9, 10**9), N))
w('search', f'{R.randint(-10**9, 10**9)}\n' + ' '.join(map(str, a)) + '\n')
w('search2', '7\n1 3 5 6\n'); w('search3', '0\n1 3 5 6\n'); w('search4', '5\n1 3 5 6\n')
N = n(100000); p = [R.randint(1, 10**9) for _ in range(N)]
w('koko', f'{R.randint(N, 4 * N)}\n' + ' '.join(map(str, p)) + '\n')
w('koko2', '8\n3 6 7 11\n'); w('koko3', '5\n30 11 23 4 20\n'); w('koko4', '6\n30 11 23 4 20\n')
side = max(4, int(1000 * S ** 0.5))
g = [[0 if R.random() < 0.2 else 1 for _ in range(side)] for _ in range(side)]
for _ in range(max(1, side // 50)): g[R.randrange(side)][R.randrange(side)] = 2
q = deque((i, j) for i in range(side) for j in range(side) if g[i][j] == 2); seen = set(q)
while q:   # fresh oranges no rotten one can reach become empty, so the answer is not -1
    i, j = q.popleft()
    for y, x in ((i+1, j), (i-1, j), (i, j+1), (i, j-1)):
        if 0 <= y < side and 0 <= x < side and g[y][x] and (y, x) not in seen: seen.add((y, x)); q.append((y, x))
for i in range(side):
    for j in range(side):
        if g[i][j] == 1 and (i, j) not in seen: g[i][j] = 0
w('oranges', ''.join(''.join(map(str, r)) + '\n' for r in g))
w('oranges2', '211\n011\n101\n'); w('oranges3', '0\n'); w('oranges4', '2\n'); w('oranges5', '211\n110\n011\n')
N = n(200000); o = list(range(N)); R.shuffle(o); e = []
for _ in range(2 * N):   # a DAG: b before a in the order o
    i, j = sorted(R.sample(range(N), 2)); e += [o[j], o[i]]
w('course', f'{N}\n' + ' '.join(map(str, e)) + '\n')
w('course2', '3\n1 0 2 1 0 2\n'); w('course3', '2\n'); w('course4', '2\n1 0\n')
N = n(100000); o = list(range(1, N + 1)); R.shuffle(o); e = []
for i in range(1, N): e += [o[R.randrange(i)], o[i], R.randint(1, 100)]   # every vertex reachable from o[0]
for _ in range(4 * N): e += [R.randint(1, N), R.randint(1, N), R.randint(1, 100)]
w('delay', f'{N} {o[0]}\n' + ' '.join(map(str, e)) + '\n')
w('delay2', '3 1\n1 2 5 3 2 1\n'); w('delay3', '2 2\n1 2 1\n'); w('delay4', '4 2\n2 1 1 2 3 1 3 4 1\n')
N = n(500000); e = [[i, R.randrange(1, i)] for i in range(2, N + 1)]   # a tree, plus one edge
u, v = R.sample(range(1, N + 1), 2); e.append([u, v]); R.shuffle(e)
for x in e: R.shuffle(x)
w('redundant', f'{N}\n' + ' '.join(f'{x} {y}' for x, y in e) + '\n')
w('redundant2', '3\n1 2 1 3 2 3\n'); w('redundant3', '5\n1 2 2 3 3 4 1 4 1 5\n')
A = n(100000); c = R.sample(range(5, 1000), 20)
w('coins', f'{A}\n' + ' '.join(map(str, c)) + '\n')
w('coins2', '3\n2\n'); w('coins3', '0\n1\n'); w('coins4', '11\n1 2 5\n'); w('coins5', '7\n2 4\n')
L = max(4, int(2000 * S ** 0.5))
w('lcs', ''.join(R.choice('abcd') for _ in range(L)) + '\n' + ''.join(R.choice('abcd') for _ in range(L)) + '\n')
w('lcs2', 'abcde\nace\n'); w('lcs3', 'abc\ndef\n'); w('lcs4', 'a\na\n')
w('temps', ' '.join(str(R.randint(30, 100)) for _ in range(n(1000000))) + '\n')
w('temps2', '73 74 75 71 69 72 76 73\n'); w('temps3', '30 60 90\n')
w('bits', f'{n(1000000)}\n'); w('bits2', '0\n'); w('bits3', '5\n')
