import sys
t = list(map(int, sys.stdin.read().split()))
out = [0] * len(t)
st = []
for i, x in enumerate(t):
    while st and t[st[-1]] < x:
        j = st.pop()
        out[j] = i - j
    st.append(i)
print(*out)
