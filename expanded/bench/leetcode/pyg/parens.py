s=[0]
for c in input():
 if c in'([{':s+=c
 elif s.pop()!='([{'[')]}'.find(c)]:s=0;break
print(['false','true'][s==[0]])
