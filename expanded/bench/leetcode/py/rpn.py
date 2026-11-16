import sys
st = []
for tok in sys.stdin.read().split():
    if tok in ('+', '-', '*', '/'):
        b = st.pop(); a = st.pop()
        if tok == '+': st.append(a + b)
        elif tok == '-': st.append(a - b)
        elif tok == '*': st.append(a * b)
        else: st.append(abs(a) // abs(b) * (1 if (a < 0) == (b < 0) else -1))
    else:
        st.append(int(tok))
print(st[-1])
