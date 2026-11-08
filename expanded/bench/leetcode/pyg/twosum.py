t,*a=map(int,open(0).read().split());d={}
for i,x in enumerate(a):
 if t-x in d:print(d[t-x],i);break
 d[x]=i
