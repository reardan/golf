#include <bits/stdc++.h>
using namespace std;
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    vector<long> a; long x;
    while (cin >> x) a.push_back(x);
    int n = a.size();
    vector<long> out(n);
    long p = 1;
    for (int i = 0; i < n; i++) { out[i] = p; p *= a[i]; }
    p = 1;
    for (int i = n - 1; i >= 0; i--) { out[i] *= p; p *= a[i]; }
    for (long v : out) cout << v << ' ';
}
