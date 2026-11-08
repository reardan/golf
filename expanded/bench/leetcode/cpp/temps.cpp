#include <cstdio>
#include <vector>
int main() {
    std::vector<int> t, st;
    int x;
    while (scanf("%d", &x) == 1) t.push_back(x);
    std::vector<int> out(t.size());
    for (int i = 0; i < (int)t.size(); i++) {
        while (!st.empty() && t[st.back()] < t[i]) { out[st.back()] = i - st.back(); st.pop_back(); }
        st.push_back(i);
    }
    std::vector<char> buf;
    for (int v : out) {
        char s[16];
        int k = snprintf(s, sizeof s, "%d ", v);
        buf.insert(buf.end(), s, s + k);
    }
    buf.push_back('\n');
    fwrite(buf.data(), 1, buf.size(), stdout);
}
