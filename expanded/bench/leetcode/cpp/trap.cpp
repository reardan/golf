#include <bits/stdc++.h>
using namespace std;
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    vector<long> h; long x;
    while (cin >> x) h.push_back(x);
    int n = h.size();
    vector<long> L(n), R(n);
    for (int i = 0; i < n; i++) L[i] = max(h[i], i ? L[i - 1] : 0);
    for (int i = n - 1; i >= 0; i--) R[i] = max(h[i], i < n - 1 ? R[i + 1] : 0);
    long s = 0;
    for (int i = 0; i < n; i++) s += min(L[i], R[i]) - h[i];
    cout << s;
}
