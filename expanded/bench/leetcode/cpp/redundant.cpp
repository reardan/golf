#include <cstdio>
#include <numeric>
#include <vector>
int main() {
    int n, a, b;
    if (scanf("%d", &n) != 1) return 0;
    std::vector<int> p(n + 1);
    std::iota(p.begin(), p.end(), 0);
    auto find = [&](int x) {
        while (p[x] != x) x = p[x] = p[p[x]];
        return x;
    };
    while (scanf("%d %d", &a, &b) == 2) {
        int x = find(a), y = find(b);
        if (x == y) { printf("%d %d\n", a, b); return 0; }
        p[x] = y;
    }
}
