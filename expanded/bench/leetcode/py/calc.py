import sys
s = sys.stdin.readline()
res, num, sign, st = 0, 0, 1, []
for c in s:
    if c.isdigit():
        num = num * 10 + int(c)
    elif c in '+-':
        res += sign * num; num = 0
        sign = 1 if c == '+' else -1
    elif c == '(':
        st.append((res, sign)); res, sign = 0, 1
    elif c == ')':
        res += sign * num; num = 0
        r, sg = st.pop(); res = r + sg * res
res += sign * num
print(res)
