def ways(s):
    a, b = 0, 1
    for i, c in enumerate(s):
        a, b = b, (b if c != '0' else 0) + (a if i and 10 <= int(s[i-1:i+1]) <= 26 else 0)
    return b
def gen(R, S, w):
    n = max(4, int(1000000 * S)); q = 0.0002
    while True:   # mostly forced pieces, a few ambiguous ones, so the count fits in 62 bits
        t, L = [], 0
        while L < n:
            x = R.choice(['1', '2']) if R.random() < q else R.choice(['10', '20', '3', '4', '5', '6', '7', '8', '9'])
            t.append(x); L += len(x)
        s = ''.join(t)
        if 2**40 < ways(s) < 2**61 or (n < 1000 and 0 < ways(s) < 2**61): break
        q *= 0.9 if ways(s) >= 2**61 else 1.1
    w('', s + '\n')
    for i, c in enumerate(['12', '226', '06', '0', '10', '2101', '27', '11106', '1', '100', '1111111111', '226210', '30']):
        w(str(i + 2), c + '\n')
