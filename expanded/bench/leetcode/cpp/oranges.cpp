#include <iostream>
#include <string>
#include <utility>
#include <vector>
int main() {
    std::ios::sync_with_stdio(false);
    std::vector<std::string> g;
    std::string r;
    while (std::cin >> r) g.push_back(r);
    int R = g.size(), C = R ? g[0].size() : 0, fresh = 0, t = 0;
    std::vector<std::pair<int, int>> q, n;
    for (int i = 0; i < R; i++)
        for (int j = 0; j < C; j++) {
            if (g[i][j] == '2') q.push_back({i, j});
            if (g[i][j] == '1') fresh++;
        }
    const int dy[] = {1, -1, 0, 0}, dx[] = {0, 0, 1, -1};
    while (!q.empty() && fresh) {
        n.clear();
        for (auto [i, j] : q)
            for (int d = 0; d < 4; d++) {
                int y = i + dy[d], x = j + dx[d];
                if (y >= 0 && y < R && x >= 0 && x < C && g[y][x] == '1') {
                    g[y][x] = '2'; fresh--; n.push_back({y, x});
                }
            }
        std::swap(q, n);
        t++;
    }
    std::cout << (fresh ? -1 : t) << "\n";
}
