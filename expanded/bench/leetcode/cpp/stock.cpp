#include <bits/stdc++.h>
using namespace std;
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    long p, lo = LONG_MAX, best = 0;
    while (cin >> p) { lo = min(lo, p); best = max(best, p - lo); }
    cout << best;
}
