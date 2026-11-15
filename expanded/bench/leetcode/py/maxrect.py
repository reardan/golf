import sys
rows = sys.stdin.read().split()
C = len(rows[0])
h = [0] * (C + 1)
best = 0
for row in rows:
    for j, ch in enumerate(row):
        h[j] = h[j] + 1 if ch == '1' else 0
    st = [-1]
    for i, x in enumerate(h):
        while st[-1] != -1 and h[st[-1]] >= x:
            top = st.pop()
            best = max(best, h[top] * (i - st[-1] - 1))
        st.append(i)
print(best)
