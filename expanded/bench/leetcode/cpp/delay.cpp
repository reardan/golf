#include <cstdio>
#include <functional>
#include <queue>
#include <utility>
#include <vector>
int main() {
    int n, k, u, v, w;
    if (scanf("%d %d", &n, &k) != 2) return 0;
    std::vector<std::vector<std::pair<int, int>>> adj(n + 1);
    while (scanf("%d %d %d", &u, &v, &w) == 3) adj[u].push_back({v, w});
    std::vector<long long> dist(n + 1, -1);
    std::priority_queue<std::pair<long long, int>, std::vector<std::pair<long long, int>>, std::greater<>> h;
    h.push({0, k});
    while (!h.empty()) {
        auto [d, x] = h.top(); h.pop();
        if (dist[x] >= 0) continue;
        dist[x] = d;
        for (auto [y, c] : adj[x]) if (dist[y] < 0) h.push({d + c, y});
    }
    long long best = 0;
    for (int i = 1; i <= n; i++) {
        if (dist[i] < 0) { puts("-1"); return 0; }
        if (dist[i] > best) best = dist[i];
    }
    printf("%lld\n", best);
}
