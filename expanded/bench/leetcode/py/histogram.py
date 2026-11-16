import sys
h = list(map(int, sys.stdin.read().split())) + [0]
st = [-1]
best = 0
for i, x in enumerate(h):
    while st[-1] != -1 and h[st[-1]] >= x:
        top = st.pop()
        best = max(best, h[top] * (i - st[-1] - 1))
    st.append(i)
print(best)
