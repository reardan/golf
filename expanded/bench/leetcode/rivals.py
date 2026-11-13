#!/usr/bin/env python3
"""rivals.py LANG [PROB...] [--set DIR]
Checks the Vyxal, 05AB1E and Nibbles solutions (and Golf's, from bin/) against py/.
Cases are the gen.py files in DIR (default small: `python3 gen.py 0.0001 small`).
Interpreters: vyxal on PATH (pip install vyxal); 05AB1E's osabie escript and
Nibbles' nibbles binary under $RIVALS_EXT/05AB1E and $RIVALS_EXT/nibbles.
TMO=seconds sets the per-case timeout (default 600).
Runs LANG's solution for each problem on every case in the set, checks the
answer against py/<p>.py, prints bytes, OK/FAIL and wall time.
LANG: vyxal | 05ab1e | nibbles | golf"""
import json, os, re, subprocess, sys, time, glob
H = BENCH = os.path.dirname(os.path.abspath(__file__))
EXT = os.environ.get('RIVALS_EXT', os.path.expanduser('~/rivals'))
TMO = int(os.environ.get("TMO", "600"))
PROBS = 'twosum parens stock longsub prodself topk islands trap slidemax queens search koko oranges course delay redundant coins lcs temps bits'.split()
SUF = {'vyxal': 'vy', '05ab1e': 'abe', 'nibbles': 'nbl', 'golf': 'golfj'}

def conv(p, txt):
    """stdin text -> LeetCode-style argument list"""
    w = txt.split(); ints = lambda: list(map(int, w))
    if p in ('twosum', 'search'): t, *a = ints(); return [a, t]
    if p in ('parens', 'longsub'): return [txt.strip()]
    if p in ('stock', 'trap', 'prodself', 'temps'): return [ints()]
    if p in ('topk', 'slidemax'): k, *a = ints(); return [a, k]
    if p == 'koko': h, *a = ints(); return [a, h]
    if p == 'islands': return [w]
    if p == 'oranges': return [[list(map(int, r)) for r in w]]
    if p in ('queens', 'bits'): return [int(w[0])]
    if p == 'course': n, *e = ints(); return [n, [e[i:i+2] for i in range(0, len(e), 2)]]
    if p == 'delay': n, k, *e = ints(); return [[e[i:i+3] for i in range(0, len(e), 3)], n, k]
    if p == 'redundant': n, *e = ints(); return [[e[i:i+2] for i in range(0, len(e), 2)]]
    if p == 'coins': a, *c = ints(); return [c, a]
    if p == 'lcs': return w[:2]
    raise KeyError(p)

def norm(o):
    o = re.sub(r'\btrue\b|\bTrue\b', '1', o); o = re.sub(r'\bfalse\b|\bFalse\b', '0', o)
    return ' '.join(re.findall(r'-?\d+', o))

def lit(x): return json.dumps(x, separators=(',', ':'))

def nib_sample(f):
    # Nibbles needs the argument types when it compiles: give it one small case's arguments
    p = os.path.basename(f).rsplit('.', 1)[0]
    return [lit(x) for x in conv(p, open(f'{H}/small/{p}.txt').read())]

def code_bytes(lang, f):
    if lang == 'nibbles':
        r = subprocess.run([f'{EXT}/nibbles/nibbles', '-c', f] + nib_sample(f), capture_output=True, text=True, cwd=f'{EXT}/nibbles')
        m = re.search(r'wrote (\d+) bytes', r.stdout + r.stderr)
        nb = f[:-4] + '.nbb'
        # nibbles counts in half bytes; -c writes ceil(n/2) bytes
        return int(m.group(1)) if m else -1
    if lang == 'golf':
        r = subprocess.run(['bash', '-c', f'python3 {BENCH}/../../tools/codepage.py encode < {f} | tr -d "\\n" | wc -c'], capture_output=True, text=True)
        try: return int(r.stdout.split()[-1])
        except Exception: return -1
    return len(open(f, encoding='utf-8').read().rstrip('\n'))

def build(lang, p, f):
    """returns a function args->cmd,stdin"""
    if lang == 'vyxal':
        def mk(a, txt):
            open(f'{H}/bin/vy.in', 'w').write('\n'.join(map(lit, a)) + '\n')
            return ['vyxal', f, 'f', f'{H}/bin/vy.in'], ''
        os.makedirs(f'{H}/bin', exist_ok=True); return mk
    if lang == '05ab1e':
        return lambda a, txt: ([f'{EXT}/05AB1E/osabie', f], '\n'.join(x if isinstance(x, str) else lit(x) for x in a) + '\n')
    if lang == 'nibbles':
        nd = f'{EXT}/nibbles'; b = f'{H}/bin/nib_{p}'; os.makedirs(f'{H}/bin', exist_ok=True)
        src = os.path.getmtime(f)
        if not os.path.exists(b) or os.path.getmtime(b) < src:
            r = subprocess.run(['./nibbles', '-hs', f] + nib_sample(f), cwd=nd, capture_output=True, text=True)
            if r.returncode: print(r.stderr[-800:]); return None
            od = f'{H}/bin/o_{p}'; os.makedirs(od, exist_ok=True)
            r = subprocess.run(['ghc', '-O', '-outputdir', od, f'{nd}/out.hs', '-o', b], capture_output=True, text=True)
            if r.returncode: print(r.stderr[-800:]); return None
        return lambda a, txt: ([b] + [lit(x) for x in a], '')
    if lang == 'golf':
        b = f'{BENCH}/bin/{p}'
        return lambda a, txt: ([b], txt)

def main():
    args = sys.argv[1:]; lang = args.pop(0); st = 'small'; timing = False; probs = []
    while args:
        x = args.pop(0)
        if x == '--set': st = args.pop(0)
        elif x == '--time': timing = True
        else: probs.append(x)
    probs = probs or PROBS
    d = st if st.startswith('/') else f'{H}/{st}'
    tot = 0; allok = True
    for p in probs:
        f = f'{H}/{lang}/{p}.{SUF[lang]}' if lang != 'golf' else f'{BENCH}/golf/{p}.golfj'
        if not os.path.exists(f): print(f'{p:9} --- missing'); allok = False; continue
        nb = code_bytes(lang, f); tot += max(nb, 0)
        mk = build(lang, p, f)
        if mk is None: print(f'{p:9} {nb:4} BUILD FAIL'); allok = False; continue
        res = []; tt = 0
        for case in sorted(glob.glob(f'{d}/{p}.txt') + glob.glob(f'{d}/{p}[0-9].txt')):
            txt = open(case).read()
            exp = norm(subprocess.run(['python3', f'{BENCH}/py/{p}.py'], input=txt, capture_output=True, text=True).stdout)
            cmd, inp = mk(conv(p, txt), txt)
            s = time.perf_counter()
            try:
                r = subprocess.run(cmd, input=inp, capture_output=True, text=True, timeout=TMO)
                out = r.stdout; err = r.stderr
            except subprocess.TimeoutExpired:
                out = 'TIMEOUT'; err = ''
            e = time.perf_counter() - s; tt += e
            got = norm(out)
            ok = got == exp
            if not ok:
                allok = False
                res.append(f'FAIL {os.path.basename(case)} exp={exp[:40]!r} got={got[:40]!r} {out[:60]!r} {err.strip()[-200:]!r}')
            else: res.append('ok')
        status = 'OK' if all(r == 'ok' for r in res) else ' | '.join(r for r in res if r != 'ok')
        print(f'{p:9} {nb:4}B  {tt:8.3f}s  {status}', flush=True)
    print(f'total {tot} bytes', 'ALL OK' if allok else 'SOME FAIL')

main()
