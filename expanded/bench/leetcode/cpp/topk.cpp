#include <bits/stdc++.h>
using namespace std;
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    int k; long x; cin >> k;
    unordered_map<long, int> c;
    while (cin >> x) c[x]++;
    vector<pair<int, long>> v;
    for (auto& [val, cnt] : c) v.push_back({-cnt, val});
    sort(v.begin(), v.end());
    for (int i = 0; i < k; i++) cout << v[i].second << ' ';
}
