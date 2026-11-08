import random, subprocess, time, sys, os, re
B = os.path.dirname(os.path.abspath(__file__)); J = os.environ.get('JELLY', 'jelly-eu')  # a command that runs: jelly eu CODE ARGS...
R = random.Random(7)
def gen(p, n):
    if p == 'twosum':
        a = R.sample(range(-10**6, 10**6), n); t = a[-2] + a[-1]
        return f'{t}\n' + ' '.join(map(str, a)), [str(a), str(t)]
    if p == 'parens':
        st, out, op = [], [], 0
        while op < n // 2 or st:
            if op < n // 2 and (not st or R.random() < .5):
                c = R.choice('([{'); st.append(')]}'['([{'.index(c)]); out.append(c); op += 1
            else: out.append(st.pop())
        s = ''.join(out); return s, ['"' + s + '"']
    if p in ('stock', 'trap', 'prodself'):
        a = [R.choice([1, -1]) for _ in range(n)] if p == 'prodself' else [R.randint(0, 10**4) for _ in range(n)]
        return ' '.join(map(str, a)), [str(a)]
    if p == 'longsub':
        s = ''.join(R.choice('abcdefghijklmnopqrstuvwxyz') for _ in range(n)); return s, ['"' + s + '"']
    if p == 'topk':
        a = [int(R.paretovariate(1.2)) % 1000 for _ in range(n)]
        return '3\n' + ' '.join(map(str, a)), [str(a), '3']
    if p == 'islands':
        g = [''.join(R.choice('01') for _ in range(n)) for _ in range(n)]
        return '\n'.join(g) + '\n', [str(g).replace("'", '"')]
    if p == 'slidemax':
        a = [R.randint(-10**4, 10**4) for _ in range(n)]; return '100\n' + ' '.join(map(str, a)), [str(a), '100']
    if p == 'queens': return str(n), [str(n)]
def run(cmd, inp=None):
    s = time.perf_counter()
    r = subprocess.run(cmd, input=inp, capture_output=True, text=True, timeout=600)
    return time.perf_counter() - s, r.stdout
def norm(o): return ' '.join(re.sub(r'[\[\],]', ' ', o.replace('true', '1').replace('false', '0')).split())
for p, n in [(a, int(b)) for a, b in (x.split('=') for x in sys.argv[1:])]:
    inp, args = gen(p, n)
    code = open(f'{B}/jelly/{p}.jelly', encoding='utf-8').read()
    tj, oj = run(J.split() + [code] + args)
    tp, op = run(['python3', f'{B}/py/{p}.py'], inp)
    tg, og = run([f'{B}/bin/{p}'], inp)
    tc, oc = run([f'{B}/bin/{p}_cpp'], inp)
    ok = 'OK' if len({norm(oj), norm(op), norm(og), norm(oc)}) == 1 else f'MISMATCH j={norm(oj)[:30]} p={norm(op)[:30]} g={norm(og)[:30]}'
    print(f'{p:9} n={n:<6} jelly {tj:8.3f}  py {tp:6.3f}  golf {tg:6.3f}  cpp {tc:6.3f}  {ok}', flush=True)
