#include <cstdio>
#include <vector>
int main() {
    int n;
    if (scanf("%d", &n) != 1) return 0;
    std::vector<int> ans(n + 1);
    std::vector<char> buf;
    for (int i = 0; i <= n; i++) {
        if (i) ans[i] = ans[i >> 1] + (i & 1);
        char s[16];
        int k = snprintf(s, sizeof s, "%d ", ans[i]);
        buf.insert(buf.end(), s, s + k);
    }
    buf.push_back('\n');
    fwrite(buf.data(), 1, buf.size(), stdout);
}
