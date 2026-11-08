#include <cstdio>
#include <vector>
int main() {
    int amount, c;
    std::vector<int> coins;
    if (scanf("%d", &amount) != 1) return 0;
    while (scanf("%d", &c) == 1) coins.push_back(c);
    std::vector<int> dp(amount + 1, amount + 1);
    dp[0] = 0;
    for (int i = 1; i <= amount; i++)
        for (int x : coins)
            if (x <= i && dp[i - x] + 1 < dp[i]) dp[i] = dp[i - x] + 1;
    printf("%d\n", dp[amount] > amount ? -1 : dp[amount]);
}
