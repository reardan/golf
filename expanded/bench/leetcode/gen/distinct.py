def gen(R, S, w):
    def count(s, t):
        dp = [1] + [0] * len(t)
        for c in s:
            for j in range(len(t), 0, -1):
                if t[j - 1] == c: dp[j] += dp[j - 1]
        return dp[-1]
    n = max(4, int(3000 * S ** 0.5)); s = ''.join(R.choice('abcdefghijklmnopqrstuvwxyz') for _ in range(n))
    m = max(1, n // 2)
    while True:   # t a random subsequence of s, long enough that the count fits in 31 bits (LeetCode: a 32-bit answer)
        idx = sorted(R.sample(range(n), min(m, n))); t = ''.join(s[i] for i in idx)
        if count(s, t) < 2 ** 31: break
        m += max(1, n // 20)
    w('', s + '\n' + t + '\n')
    w('2', 'rabbbit\nrabbit\n'); w('3', 'babgbag\nbag\n'); w('4', 'abc\nabcd\n'); w('5', 'a\nb\n')
    w('6', 'aaaaaaaaaa\naaa\n'); w('7', 'b\nb\n'); w('8', 'ab\nba\n'); w('9', 'a' * 800 + 'b\n' + 'a' * 400 + 'c\n')
