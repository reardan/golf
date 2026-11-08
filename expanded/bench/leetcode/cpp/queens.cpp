#include <bits/stdc++.h>
using namespace std;
long full;
long solve(long cols, long d1, long d2) {
    if (cols == full) return 1;
    long total = 0, avail = ~(cols | d1 | d2) & full;
    while (avail) {
        long bit = avail & -avail;
        avail ^= bit;
        total += solve(cols | bit, (d1 | bit) << 1, (d2 | bit) >> 1);
    }
    return total;
}
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    int n; cin >> n;
    full = (1L << n) - 1;
    cout << solve(0, 0, 0);
}
