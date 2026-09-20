#!/usr/bin/env bash
# gates.sh - static gate analysis of the divider_array (problem4) netlist
#
# Usage:  cd problem4 && ./gates.sh [N]     e.g.  ./gates.sh 8
#         (or: problem4/gates.sh [N] from the repo root; default: 4)
#
# Notes:
#   - delays (D) are irrelevant here: sv2v/yosys drop them; depth x D is the
#     corresponding worst-case propagation delay
set -euo pipefail

N="${1:-4}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# design sources, in dependency order (same set as problem.env)
SOURCES=(
  "$REPO_ROOT/problem4/src/divider_array.v"
  "$REPO_ROOT/common/lib/gates.v"
  "$REPO_ROOT/common/lib/full_adder.v"
  "$REPO_ROOT/common/lib/cas.v"
  "$REPO_ROOT/common/lib/cas_row.v"
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# yosys script
cat > "$TMP/script.ys" <<EOF
read_verilog $TMP/converted.v
chparam -set N $N divider_array
hierarchy -top divider_array
proc
flatten
delete t:\$scopeinfo
opt_clean
stat
ltp
EOF

# convert SystemVerilog -> Verilog-2005, then elaborate and analyse
sv2v "${SOURCES[@]}" > "$TMP/converted.v"
yosys -s "$TMP/script.ys" > "$TMP/out.log" 2>&1

# summarise
awk '
  /=== divider_array ===/               { in_stat = 1 }
  in_stat && /^[ ]*[0-9]+[ ]+\$/        { gsub(/[ $]/, "", $2); counts[$2] = $1; if ($2 != "buf") total += $1 }
  /Longest topological path/            { match($0, /length=[0-9]+/); depth = substr($0, RSTART + 7, RLENGTH - 7) }
  END {
    printf "divider_array  N=%d\n", "'"$N"'"
    printf "  gates      : and=%d or=%d xor=%d not=%d\n", counts["and"], counts["or"], counts["xor"], counts["not"]
    printf "  total      : %d gates (bufs excluded)\n", total
    printf "  max depth  : %d gates (longest path)\n", depth
  }
' "$TMP/out.log"
