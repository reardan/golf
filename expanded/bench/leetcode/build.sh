#!/bin/bash
# build.sh — compile every Golf and C++ solution into bin/ (gitignored)
set -e
B=$(cd "$(dirname "$0")" && pwd); G=$(cd "$B/../.." && pwd)
mkdir -p "$B/bin"
for f in "$B"/golf/*.golfj; do n=$(basename "$f" .golfj); (cd "$G" && tools/golfc -j "$f" "$B/bin/$n"); done
for f in "$B"/cpp/*.cpp; do n=$(basename "$f" .cpp); g++ -O2 -std=c++17 -o "$B/bin/${n}_cpp" "$f"; done
