#include <algorithm>
#include <iostream>
#include <string>
#include <vector>
int main() {
    std::string a, b;
    std::cin >> a >> b;
    size_t n = b.size();
    std::vector<int> prev(n + 1), cur(n + 1);
    for (char ch : a) {
        for (size_t j = 1; j <= n; j++)
            cur[j] = ch == b[j - 1] ? prev[j - 1] + 1 : std::max(prev[j], cur[j - 1]);
        std::swap(prev, cur);
    }
    std::cout << prev[n] << "\n";
}
