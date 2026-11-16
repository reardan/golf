135 Candy, Hard. Input: the ratings.
Golf `⟦2≺⊟1⍳\\⧺⟦\\⊕$⟧⍀⟧⥮⌈⊕∑`, 19 bytes. The verb in the block counts, for each child, how many rises in a row end there: `2≺⊟` flags each rise (-1), `1⍳\\⧺` puts a 0 in front for the first child, and the scan `(acc+1) & flag` (`\\⊕$`) counts the run. `⥮` runs it from the left and (on the reversed list) from the right; `⌈⊕∑` adds 1 + the larger count over the children. O(n).
Full: `full  golf 0.091s  py 0.192s  OK` (500k ratings in runs up and down).
Gaps: `2≺⊟` gives n-1 values, and getting back to n (`1⍳\\⧺`, 4 bytes) is the same missing "shift/prepend" word as in square.
