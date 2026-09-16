#!/usr/bin/env bash
# ==========================================================================
# wave.sh - simulate a problem, then open its waveforms in GTKWave
#
# Usage:  ./wave.sh [problem-dir]        e.g.  ./wave.sh problem1
#         cd problem1 && ../wave.sh      (defaults to the current directory)
#
# VCD_FILE / GTKW_SAVE come from the problem's problem.env. If the .gtkw
# file exists it is passed to gtkwave to pre-load a signal layout (save
# over it from gtkwave's File menu to keep your own layout).
# ==========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROBLEM_DIR="$(cd "${1:-.}" 2>/dev/null && pwd)" || {
    echo "error: problem directory '${1:-.}' does not exist" >&2
    exit 1
}

ENV_FILE="$PROBLEM_DIR/problem.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "error: $ENV_FILE not found (see problem1/ for a template)" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${VCD_FILE:?problem.env must define VCD_FILE}"

# run the simulation (re)generating the VCD
"$REPO_ROOT/sim.sh" "$PROBLEM_DIR"

VCD="$PROBLEM_DIR/$VCD_FILE"
GTKW="$PROBLEM_DIR/${GTKW_SAVE:-}"

if [ ! -s "$VCD" ]; then
    echo "error: $VCD was not produced - does \$dumpfile in the testbench match VCD_FILE?" >&2
    exit 1
fi

if ! command -v gtkwave >/dev/null 2>&1; then
    echo "gtkwave not found in PATH."
    echo "  enter the dev shell first:  nix develop"
    echo "  then view manually:         gtkwave $VCD"
    exit 0
fi

if [ -f "$GTKW" ]; then
    gtkwave "$VCD" "$GTKW" &
else
    gtkwave "$VCD" &
fi
