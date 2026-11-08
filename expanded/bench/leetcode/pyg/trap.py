from itertools import*
h=[*map(int,open(0).read().split())];A=accumulate
print(sum(map(min,A(h,max),[*A(h[::-1],max)][::-1]))-sum(h))
