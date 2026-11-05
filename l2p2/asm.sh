#!/usr/bin/env bash
# asm.sh - assemble the l2p2 programs into the hex images the
# testbenches $readmemh (sim.sh does not do this for you)
#
# Usage:  cd l2p2 && ./asm.sh        (or: l2p2/asm.sh from the repo root)
#
#   asm/prog.asm  -> sim/program.hex  (cpu_tb; default 8-bit instance)
#   asm/math.asm  -> sim/math.hex     (math_tb; 64-bit instance)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DIR/sim"
python3 "$DIR/asm/asm.py" "$DIR/asm/prog.asm" -o "$DIR/asm/program.hex"
python3 "$DIR/asm/asm.py" "$DIR/asm/math.asm" --bits 64 --addr-bits 7 \
    --imm-bits 8 --lanes 0 -o "$DIR/asm/math.hex"
