#!/usr/bin/env bash
# gates.sh - static gate analysis of the divider (problem5) netlist
#
# Usage:  cd problem5 && ./gates.sh [N]     e.g.  ./gates.sh 8
#         (or: problem5/gates.sh [N] from the repo root; default: 4)
#
# Notes:
#   - delays (DG/DD) are irrelevant here: yosys drop them; depth x DG
#     is the corresponding worst-case per-cycle propagation delay
set -euo pipefail

N="${1:-4}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# design sources, in dependency order (same set as problem.env)
SOURCES=(
  "$REPO_ROOT/problem5/src/divider.v"
  "$REPO_ROOT/common/lib/gates.v"
  "$REPO_ROOT/common/lib/full_adder.v"
  "$REPO_ROOT/common/lib/cas.v"
  "$REPO_ROOT/common/lib/cas_row.v"
  "$REPO_ROOT/common/lib/carry_gen.v"
  "$REPO_ROOT/common/lib/lookahead_adder.v"
  "$REPO_ROOT/common/lib/mux.v"
  "$REPO_ROOT/common/lib/dff_sc.v"
  "$REPO_ROOT/common/lib/piso_reg.v"
  "$REPO_ROOT/common/lib/piso_msb_reg.v"
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# yosys script
cat > "$TMP/script.ys" <<EOF
read_verilog $TMP/converted.v
chparam -set N $N divider
hierarchy -top divider
proc
flatten
delete t:\$scopeinfo
opt_clean
stat -width
ltp -noff
EOF

# convert SystemVerilog -> Verilog-2005, then elaborate and analyse
sv2v "${SOURCES[@]}" > "$TMP/converted.v"
yosys -s "$TMP/script.ys" > "$TMP/out.log" 2>&1

# summarise (stat -width annotates cell types as $type_width, e.g. $dff_4)
awk '
  /=== divider ===/                     { in_stat = 1 }
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
    printf "divider  N=%d\n", "'"$N"'"
    printf "  gates      : and=%d or=%d xor=%d not=%d\n", counts["and"], counts["or"], counts["xor"], counts["not"]
    printf "  registers  : %d flip-flops in %d cells (clear muxes: %d bits in %d cells)\n", ff, ff_cells, mx, mx_cells
    printf "  total      : %d gates (bufs and registers excluded)\n", total
    printf "  max depth  : %d gates (longest register-to-register path)\n", depth
  }
' "$TMP/out.log"
