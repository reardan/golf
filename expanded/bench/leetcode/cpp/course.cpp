#include <cstdio>
#include <vector>
int main() {
    int n, a, b;
    if (scanf("%d", &n) != 1) return 0;
    std::vector<std::vector<int>> adj(n);
    std::vector<int> deg(n), q;
    while (scanf("%d %d", &a, &b) == 2) { adj[b].push_back(a); deg[a]++; }
    for (int i = 0; i < n; i++) if (!deg[i]) q.push_back(i);
    for (size_t h = 0; h < q.size(); h++)
        for (int v : adj[q[h]]) if (!--deg[v]) q.push_back(v);
    puts((int)q.size() == n ? "true" : "false");
}
