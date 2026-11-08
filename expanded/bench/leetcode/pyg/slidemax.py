k,*a=map(int,open(0).read().split());d=[];o=[];h=0
for i,x in enumerate(a):
 while d[h:]and a[d[-1]]<=x:d.pop()
 d+=i,;h+=d[h]<=i-k
 if i>=k-1:o+=a[d[h]],
print(*o)
