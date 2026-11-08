#include <algorithm>
#include <cstdio>
#include <vector>
int main() {
    long long t, x;
    std::vector<long long> a;
    if (scanf("%lld", &t) != 1) return 0;
    while (scanf("%lld", &x) == 1) a.push_back(x);
    printf("%ld\n", std::lower_bound(a.begin(), a.end(), t) - a.begin());
}
