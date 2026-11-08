#include <bits/stdc++.h>
using namespace std;
int main() {
    ios::sync_with_stdio(false); cin.tie(nullptr);
    string s; cin >> s;
    string st;
    for (char c : s) {
        if (c == '(' || c == '[' || c == '{') st += c;
        else {
            char o = c == ')' ? '(' : c == ']' ? '[' : '{';
            if (st.empty() || st.back() != o) { cout << "false"; return 0; }
            st.pop_back();
        }
    }
    cout << (st.empty() ? "true" : "false");
}
