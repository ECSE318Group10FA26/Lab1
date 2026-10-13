#!/usr/bin/env bash
# gates.sh - static gate analysis of the alu_core (l2p1) netlist
#
# Usage:  cd l2p1 && ./gates.sh [N]     e.g.  ./gates.sh 8
#         (or: l2p1/gates.sh [N] from the repo root; default: 16)
#
# Notes:
#   - delays (D) are irrelevant here: sv2v/yosys drop them; depth x D is the
#     corresponding worst-case propagation delay
#   - the ALU is purely combinational, so the longest path is input-to-output
set -euo pipefail

N="${1:-16}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# design sources, in dependency order (same set as problem.env's LIB_DIRS,
# minus what the ALU tree never instantiates: regfile, ram, dff_sc, ...)
SOURCES=(
  "$REPO_ROOT/common/lib/structural/alu/alu_core.v"
  "$REPO_ROOT/common/lib/structural/alu/arith_unit.v"
  "$REPO_ROOT/common/lib/structural/alu/logic_unit.v"
  "$REPO_ROOT/common/lib/structural/alu/shift_unit.v"
  "$REPO_ROOT/common/lib/structural/alu/comp_unit.v"
  "$REPO_ROOT/common/lib/structural/lookahead_adder.v"
  "$REPO_ROOT/common/lib/structural/carry_gen.v"
  "$REPO_ROOT/common/lib/structural/mux.v"
  "$REPO_ROOT/common/lib/structural/bit_rev.v"
  "$REPO_ROOT/common/lib/structural/gates.v"
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# yosys script
cat >"$TMP/script.ys" <<EOF
read_verilog $TMP/converted.v
chparam -set N $N alu_core
hierarchy -top alu_core
proc
flatten
delete t:\$scopeinfo
opt_clean
stat
ltp
EOF

# convert SystemVerilog -> Verilog-2005, then elaborate and analyse
sv2v "${SOURCES[@]}" >"$TMP/converted.v"
yosys -s "$TMP/script.ys" >"$TMP/out.log" 2>&1

# summarise
awk '
  /=== alu_core ===/                    { in_stat = 1 }
  in_stat && /^[ ]*[0-9]+[ ]+\$/        { gsub(/[ $]/, "", $2); counts[$2] = $1; if ($2 != "buf") total += $1 }
  /Longest topological path/            { match($0, /length=[0-9]+/); depth = substr($0, RSTART + 7, RLENGTH - 7) }
  END {
    printf "alu_core  N=%d\n", "'"$N"'"
    printf "  gates      : and=%d or=%d xor=%d not=%d\n", counts["and"], counts["or"], counts["xor"], counts["not"]
    printf "  total      : %d gates (bufs excluded)\n", total
    printf "  max depth  : %d gates (longest input-to-output path)\n", depth
  }
' "$TMP/out.log"
