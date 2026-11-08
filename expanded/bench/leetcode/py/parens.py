import sys
s = sys.stdin.read().strip()
pair = {')': '(', ']': '[', '}': '{'}
st = []
ok = True
for c in s:
    if c in pair:
        if not st or st.pop() != pair[c]:
            ok = False
            break
    else:
        st.append(c)
print("true" if ok and not st else "false")
