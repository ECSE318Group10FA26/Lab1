#!/usr/bin/env bash
# gates.sh - static gate analysis of the cpu (l2p2) netlist
#
# Usage:  cd l2p2 && ./gates.sh [N] [A] [R]     e.g.  ./gates.sh 8 8 2
#         (or: l2p2/gates.sh [N] [A] [R] from the repo root;
#          defaults: 19 7 2 -- the module's own defaults)
#
#   N = RAM word size in bits (the datapath is W words wide)
#   A = RAM address bits (the memory holds 2**A words)
#   R = register-address bits (2**R registers); the remaining parameters
#       (I, SW, L, W, SZ, IW, FW, ...) derive from these three
#
# Notes:
#   - delays (D/DF) are irrelevant here: yosys drops them; depth x D is the
#     corresponding worst-case per-cycle propagation delay
set -euo pipefail

N="${1:-19}"
A="${2:-7}"
R="${3:-2}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# design sources, in dependency order (same set as problem.env's
# SOURCES + LIB_DIRS)
SOURCES=(
  "$REPO_ROOT/l2p2/src/cpu.v"
  "$REPO_ROOT/common/lib/structural/alu/alu_core.v"
  "$REPO_ROOT/common/lib/structural/alu/arith_unit.v"
  "$REPO_ROOT/common/lib/structural/alu/logic_unit.v"
  "$REPO_ROOT/common/lib/structural/alu/shift_unit.v"
  "$REPO_ROOT/common/lib/structural/alu/comp_unit.v"
  "$REPO_ROOT/common/lib/structural/lookahead_adder.v"
  "$REPO_ROOT/common/lib/structural/carry_gen.v"
  "$REPO_ROOT/common/lib/structural/regfile.v"
  "$REPO_ROOT/common/lib/structural/ram/ram.v"
  "$REPO_ROOT/common/lib/structural/mux.v"
  "$REPO_ROOT/common/lib/structural/demux.v"
  "$REPO_ROOT/common/lib/structural/dff_sc.v"
  "$REPO_ROOT/common/lib/structural/bit_rev.v"
  "$REPO_ROOT/common/lib/structural/gates.v"
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# yosys script
cat >"$TMP/script.ys" <<EOF
read_verilog $TMP/converted.v
chparam -set N $N -set A $A -set R $R cpu
hierarchy -top cpu
proc
flatten
delete t:\$scopeinfo
opt_clean
stat -width
ltp -noff
EOF

# convert SystemVerilog -> Verilog-2005, then elaborate and analyse
sv2v "${SOURCES[@]}" >"$TMP/converted.v"
yosys -s "$TMP/script.ys" >"$TMP/out.log" 2>&1

# summarise (stat -width annotates cell types as $type_width, e.g. $dff_4)
awk '
  /=== cpu ===/                         { in_stat = 1 }
  in_stat && /^[ ]*[0-9]+[ ]+\$/ {
      cnt = $1
      gsub(/[ $]/, "", $2)
      split($2, t, "_")                 # dff_4 -> type=dff, width=4
      type = t[1]; width = (2 in t) ? t[2] : 1
      if (type == "dff")      { ff += cnt * width; ff_cells += cnt }
      else if (type == "mux") { mx += cnt * width; mx_cells += cnt }
      else if (type != "buf") { counts[type] += cnt; total += cnt }
  }
  /Longest topological path/            { match($0, /length=[0-9]+/); depth = substr($0, RSTART + 7, RLENGTH - 7) }
  END {
    printf "cpu  N=%d A=%d R=%d\n", "'"$N"'", "'"$A"'", "'"$R"'"
    printf "  gates      : and=%d or=%d xor=%d not=%d\n", counts["and"], counts["or"], counts["xor"], counts["not"]
    printf "  registers  : %d flip-flops in %d cells (clear muxes: %d bits in %d cells)\n", ff, ff_cells, mx, mx_cells
    printf "  total      : %d gates (bufs and registers excluded)\n", total
    printf "  max depth  : %d gates (longest register-to-register path)\n", depth
  }
' "$TMP/out.log"
