t=[*map(int,open(0).read().split())];o=[0]*len(t);s=[]
for i,x in enumerate(t):
 while s and t[s[-1]]<x:j=s.pop();o[j]=i-j
 s+=i,
print(*o)
