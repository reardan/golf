from bisect import*
t,*a=map(int,open(0).read().split())
print(bisect_left(a,t))
