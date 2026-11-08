#include <bits/stdc++.h>
using namespace std;
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    long t, x; cin >> t;
    unordered_map<long, int> seen;
    for (int i = 0; cin >> x; i++) {
        auto it = seen.find(t - x);
        if (it != seen.end()) { cout << it->second << ' ' << i; return 0; }
        seen[x] = i;
    }
}
