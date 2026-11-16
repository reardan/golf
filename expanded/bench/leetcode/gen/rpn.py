def gen(R, S, w):
    n = max(5, int(1000000 * S))
    st, out, M = [], [], 2**31 - 1
    def ap(o):
        b = st.pop(); a = st.pop()
        if o == '+': v = a + b
        elif o == '-': v = a - b
        elif o == '*': v = a * b
        else: v = abs(a) // abs(b) * (1 if (a < 0) == (b < 0) else -1)
        st.append(v); out.append(o)
    while len(out) < n or len(st) > 1:
        if len(st) < 2 or (len(out) < n and R.random() < 0.45):
            v = R.randint(-200, 200); st.append(v); out.append(str(v)); continue
        a, b = st[-2], st[-1]
        ops = [o for o, v in (('+', a + b), ('-', a - b), ('*', a * b)) if abs(v) <= M]
        if b: ops.append('/')
        ap(R.choice(ops))
    w('', ' '.join(out) + '\n')
    w('2', '2 1 + 3 *\n'); w('3', '4 13 5 / +\n'); w('4', '10 6 9 3 + -11 * / * 17 + 5 +\n')
    w('5', '5\n'); w('6', '-7\n'); w('7', '7 -2 /\n'); w('8', '-7 2 /\n'); w('9', '0 3 -\n')
    w('10', '-3 -4 * 0 -\n')
