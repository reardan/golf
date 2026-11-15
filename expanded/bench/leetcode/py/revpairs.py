import sys
def count(a):                      # merge sort: returns the pairs, sorts a
    if len(a) < 2:
        return 0
    m = len(a) // 2
    left, right = a[:m], a[m:]
    c = count(left) + count(right)
    j = 0
    for x in left:
        while j < len(right) and x > 2 * right[j]:
            j += 1
        c += j
    a[:] = sorted(left + right)
    return c
print(count(list(map(int, sys.stdin.read().split()))))
