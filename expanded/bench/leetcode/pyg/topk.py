from collections import*
k,*a=map(int,open(0).read().split());c=Counter(a)
print(*sorted(c,key=lambda v:(-c[v],v))[:k])
