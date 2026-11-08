#include <algorithm>
#include <cstdio>
#include <vector>
int main() {
    long long h, x;
    std::vector<long long> p;
    if (scanf("%lld", &h) != 1) return 0;
    while (scanf("%lld", &x) == 1) p.push_back(x);
    long long lo = 1, hi = *std::max_element(p.begin(), p.end());
    while (lo < hi) {
        long long k = (lo + hi) / 2, s = 0;
        for (long long v : p) s += (v + k - 1) / k;
        if (s <= h) hi = k; else lo = k + 1;
    }
    printf("%lld\n", lo);
}
