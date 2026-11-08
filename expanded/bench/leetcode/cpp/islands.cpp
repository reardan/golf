#include <bits/stdc++.h>
using namespace std;
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    vector<string> g; string r;
    while (cin >> r) g.push_back(r);
    int R = g.size(), C = R ? g[0].size() : 0, n = 0;
    vector<pair<int, int>> st;
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++) {
            if (g[i][j] != '1') continue;
            n++; g[i][j] = '0'; st.push_back({i, j});
            while (!st.empty()) {
                auto [y, x] = st.back(); st.pop_back();
                int dy[] = {1, -1, 0, 0}, dx[] = {0, 0, 1, -1};
                for (int d = 0; d < 4; d++) {
                    int v = y + dy[d], u = x + dx[d];
                    if (v >= 0 && v < R && u >= 0 && u < C && g[v][u] == '1') {
                        g[v][u] = '0'; st.push_back({v, u});
                    }
                }
            }
        }
    cout << n;
}
