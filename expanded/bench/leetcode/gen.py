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
