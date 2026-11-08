a,*c=map(int,open(0).read().split());d=[0]+[a+1]*a
for i in range(1,a+1):d[i]=min([d[i-x]+1 for x in c if x<=i]+[a+1])
print([d[a],-1][d[a]>a])
