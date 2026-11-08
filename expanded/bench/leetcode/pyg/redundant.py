n,*e=map(int,open(0).read().split());p=[*range(n+1)]
def f(x):
 while p[x]-x:p[x]=x=p[p[x]]
 return x
for i in range(0,len(e),2):
 a,b=f(e[i]),f(e[i+1])
 if a==b:print(e[i],e[i+1]);break
 p[a]=b
