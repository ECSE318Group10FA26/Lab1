#!/usr/bin/env bash
# gates.sh - static gate analysis of the multi_adder (problem3) netlist
#
# Usage:  cd problem3 && ./gates.sh [N] [M]     e.g.  ./gates.sh 8 9
#         (or: problem3/gates.sh [N] [M] from the repo root; defaults: 8 9)
#
# Notes:
#   - delays (D) are irrelevant here: sv2v/yosys drop them; depth x D is the
#     corresponding worst-case propagation delay
#   - opt_clean prunes provably dead logic (e.g. the final adder's always-0
#     carry-out tree), so counts reflect the hardware you would actually build
set -euo pipefail

N="${1:-8}"
M="${2:-3}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# design sources, in dependency order (same set as problem.env)
SOURCES=(
  "$REPO_ROOT/problem3/src/multi_adder.v"
  "$REPO_ROOT/common/lib/gates.v"
  "$REPO_ROOT/common/lib/full_adder.v"
  "$REPO_ROOT/common/lib/carry_gen.v"
  "$REPO_ROOT/common/lib/lookahead_adder.v"
  "$REPO_ROOT/common/lib/csa.v"
  "$REPO_ROOT/common/lib/csa_layer.v"
  "$REPO_ROOT/common/lib/csa_stack.v"
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# yosys script
cat > "$TMP/script.ys" <<EOF
read_verilog $TMP/converted.v
chparam -set N $N -set M $M multi_adder
hierarchy -top multi_adder
proc
flatten
delete t:\$scopeinfo
opt_clean
show -format svg -prefix $REPO_ROOT/problem3/sim/schematic$N
stat
ltp
EOF

# convert SystemVerilog -> Verilog-2005, then elaborate and analyse
sv2v "${SOURCES[@]}" > "$TMP/converted.v"
yosys -s "$TMP/script.ys" > "$TMP/out.log" 2>&1

# summarise
awk '
  /=== multi_adder ===/                 { in_stat = 1 }
  in_stat && /^[ ]*[0-9]+[ ]+\$/        { gsub(/[ $]/, "", $2); counts[$2] = $1; total += $1 }
  /Longest topological path/            { match($0, /length=[0-9]+/); depth = substr($0, RSTART + 7, RLENGTH - 7) }
  END {
    printf "multi_adder  N=%d M=%d\n", "'"$N"'", "'"$M"'"
    printf "  gates      : and=%d or=%d xor=%d\n", counts["and"], counts["or"], counts["xor"]
    printf "  total      : %d gates\n", total
    printf "  max depth  : %d gates (longest path)\n", depth
  }
' "$TMP/out.log"
