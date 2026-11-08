h,*p=map(int,open(0).read().split());l,r=1,max(p)
while l<r:
 k=(l+r)//2
 if sum(-(-x//k)for x in p)>h:l=k+1
 else:r=k
print(l)
