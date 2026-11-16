import sys
s = sys.stdin.readline().strip()
st, best = [-1], 0
for i, c in enumerate(s):
    if c == '(':
        st.append(i)
    else:
        st.pop()
        if st:
            best = max(best, i - st[-1])
        else:
            st.append(i)
print(best)
