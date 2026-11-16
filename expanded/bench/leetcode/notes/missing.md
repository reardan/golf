268 Missing Number, Easy. Input: the numbers (n distinct values from 0 … n, one missing).
Golf `ℑ⊕\\-∑`, 5 bytes: `ℑ` keeps the input and pushes 0 … n-1, `⊕` makes it 1 … n, `\\-` subtracts the input from it elementwise, and `∑` of the differences is the missing number.
Full: `full  golf 0.102s  py 0.149s  OK` (1M numbers).
Gaps: none.
