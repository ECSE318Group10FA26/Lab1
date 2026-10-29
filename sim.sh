#!/usr/bin/env bash
# sim.sh - compile and simulate a problem using the ModelSim docker image
#
# Usage:  ./sim.sh [--local] [problem-dir]      e.g.  ./sim.sh problem1
#         cd problem1 && ../sim.sh --local      (defaults to the current directory)
#
# --local uses a locally installed ModelSim (vsim on PATH) instead of
# running the image through podman.
#
# The problem directory must contain a problem.env defining SOURCES,
# TB_SOURCE and TB_TOP (see l1p1/problem.env for a template).
# LIB_DIRS is optional: each directory's *.v files (*.vhd in vhdl mode)
# are appended to SOURCES. Output (work/, transcript.log, VCD)
set -euo pipefail
shopt -s globstar

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

USE_LOCAL=0
ARGS=()
for a in "$@"; do
  case "$a" in
  --local) USE_LOCAL=1 ;;
  *) ARGS+=("$a") ;;
  esac
done

if [ "$USE_LOCAL" -eq 1 ] && ! command -v vsim >/dev/null 2>&1; then
  echo "error: --local requires ModelSim (vsim) on PATH" >&2
  exit 1
fi

# resolve the problem directory (argument or current directory)
PROBLEM_DIR="$(cd "${ARGS[0]:-.}" 2>/dev/null && pwd)" || {
  echo "error: problem directory '${ARGS[0]:-.}' does not exist" >&2
  exit 1
}

# it must live inside the repo (the repo root is what gets mounted, and
# common/run.do is located relative to it)
case "$PROBLEM_DIR" in
"$REPO_ROOT"/*) REL="${PROBLEM_DIR#"$REPO_ROOT"/}" ;;
*)
  echo "error: problem directory must be inside $REPO_ROOT" >&2
  exit 1
  ;;
esac

# load per-problem variables
ENV_FILE="$PROBLEM_DIR/problem.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "error: $ENV_FILE not found" >&2
  echo "       each problem directory needs a problem.env (see problem1/ for a template)" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

# at least one of SOURCES / LIB_DIRS must provide design sources (verilog
# problems only; a vhdl problem's design may live entirely in the
# common/lib/vhdl libraries, with just the testbench compiled into work)
if [ "${HDL:-verilog}" = "verilog" ] && [ -z "${SOURCES:-}" ] && [ -z "${LIB_DIRS:-}" ]; then
  echo "error: problem.env must define SOURCES or LIB_DIRS" >&2
  exit 1
fi
: "${TB_SOURCE:?problem.env must define TB_SOURCE}"
: "${TB_TOP:?problem.env must define TB_TOP}"

# HDL mode selects the compiler used by run.do (vlog vs vcom) and the
# LIB_DIRS glob extension
HDL="${HDL:-verilog}"
case "$HDL" in
verilog) SRC_GLOB='*.v' ;;
vhdl)
  SRC_GLOB='*.vhd'
  # VHDL testbenches have no $dumpfile, so run.do dumps the VCD itself
  : "${VCD_FILE:?problem.env must define VCD_FILE in vhdl mode}"
  ;;
*)
  echo "error: problem.env HDL must be 'verilog' or 'vhdl' (got '$HDL')" >&2
  exit 1
  ;;
esac

# VHDL only: logical libraries under common/lib/vhdl. Every directory
# containing *.vhd files maps to a library named by its path relative to
# common/lib/vhdl, with '/' joined as '_' (e.g. util/tb -> util_tb).
# run.do compiles each into its own library before the problem sources.
# VHDL_LIBS (space-separated paths relative to common/lib/vhdl, in
# dependency order) overrides the automatic scan.
VHDL_LIB_ROOT="$REPO_ROOT/common/lib/vhdl"
VHDL_LIB_NAMES=""
VHDL_LIB_RELS=""
if [ "$HDL" = "vhdl" ]; then
  if [ -n "${VHDL_LIBS:-}" ]; then
    for rel in $VHDL_LIBS; do
      if [ ! -d "$VHDL_LIB_ROOT/$rel" ]; then
        echo "error: VHDL_LIBS entry '$rel' not found under common/lib/vhdl" >&2
        exit 1
      fi
      VHDL_LIB_RELS="$VHDL_LIB_RELS $rel"
      VHDL_LIB_NAMES="$VHDL_LIB_NAMES ${rel//\//_}"
    done
  elif [ -d "$VHDL_LIB_ROOT" ]; then
    # collect every directory containing *.vhd files (skipping files
    # directly in common/lib/vhdl, which belong to no library)
    mapfile -t lib_rels < <(
      for g in "$VHDL_LIB_ROOT"/**/*.vhd; do
        [ -e "$g" ] || continue
        rel="$(dirname "${g#"$VHDL_LIB_ROOT"/}")"
        [ "$rel" != "." ] && printf '%s\n' "$rel"
      done | sort -u
    )
    if [ "${#lib_rels[@]}" -gt 0 ]; then
      # dependency-order the libraries by their 'library <name>;'
      # cross-references (Kahn's algorithm, alphabetical tie-break)
      declare -A rel_of=() deps=() done_lib=()
      for rel in "${lib_rels[@]}"; do
        rel_of["${rel//\//_}"]="$rel"
      done
      for rel in "${lib_rels[@]}"; do
        name="${rel//\//_}"
        d=""
        while IFS= read -r ref; do
          if [ -n "${rel_of[$ref]:-}" ] && [ "$ref" != "$name" ]; then
            d="$d $ref"
          fi
        done < <(grep -hoiE '^[[:space:]]*library[[:space:]]+[a-z0-9_]+' "$VHDL_LIB_ROOT/$rel"/*.vhd | awk '{print tolower($2)}' | sort -u)
        deps[$name]="${d# }"
      done
      ordered_names=()
      while [ "${#ordered_names[@]}" -lt "${#lib_rels[@]}" ]; do
        progress=0
        while IFS= read -r name; do
          [ -n "${done_lib[$name]:-}" ] && continue
          ready=1
          for d in ${deps[$name]}; do
            [ -z "${done_lib[$d]:-}" ] && {
              ready=0
              break
            }
          done
          if [ "$ready" -eq 1 ]; then
            done_lib[$name]=1
            ordered_names+=("$name")
            progress=1
          fi
        done < <(printf '%s\n' "${!deps[@]}" | sort)
        if [ "$progress" -eq 0 ]; then
          echo "error: circular dependencies among VHDL libraries in common/lib/vhdl" >&2
          exit 1
        fi
      done
      for name in "${ordered_names[@]}"; do
        VHDL_LIB_NAMES="$VHDL_LIB_NAMES $name"
        VHDL_LIB_RELS="$VHDL_LIB_RELS ${rel_of[$name]}"
      done
    fi
  fi
  VHDL_LIB_RELS="${VHDL_LIB_RELS# }"
  VHDL_LIB_NAMES="${VHDL_LIB_NAMES# }"
fi

# expand optional library directories: each directory's source files are
# appended to SOURCES (alphabetical order within a directory)
for d in ${LIB_DIRS:-}; do
  if [ ! -d "$PROBLEM_DIR/$d" ]; then
    echo "error: library directory '$d' (from LIB_DIRS) not found in $PROBLEM_DIR" >&2
    exit 1
  fi
  for g in "$PROBLEM_DIR/$d"/**/$SRC_GLOB; do
    [ -e "$g" ] || continue # directory has no matching source files
    SOURCES="$SOURCES ${g#"$PROBLEM_DIR"/}"
  done
done

# sanity-check that all sources exist
for f in $SOURCES "$TB_SOURCE"; do
  if [ ! -f "$PROBLEM_DIR/$f" ]; then
    echo "error: source file '$f' (from problem.env) not found in $PROBLEM_DIR" >&2
    exit 1
  fi
done

mkdir -p "$PROBLEM_DIR/sim" # the testbench dumps its VCD here

if [ "$USE_LOCAL" -eq 1 ]; then
  echo "==> simulating ${PROBLEM_NAME:-$REL} (local vsim, $HDL)"
  # run from the problem dir so the relative paths in problem.env resolve,
  # mirroring the container's working directory
  (
    cd "$PROBLEM_DIR"
    export SOURCES="${SOURCES:-}" TB_SOURCE TB_TOP HDL VCD_FILE="${VCD_FILE:-}"
    export VHDL_LIB_ROOT VHDL_LIB_NAMES VHDL_LIB_RELS
    vsim -c -do "$REPO_ROOT/common/run.do"
  )
else
  echo "==> simulating ${PROBLEM_NAME:-$REL} ($HDL)"
  podman run --rm \
    -v "$REPO_ROOT:/work:Z" \
    -w "/work/$REL" \
    -e SOURCES="$SOURCES" \
    -e TB_SOURCE="$TB_SOURCE" \
    -e TB_TOP="$TB_TOP" \
    -e HDL="$HDL" \
    -e VCD_FILE="${VCD_FILE:-}" \
    -e VHDL_LIB_ROOT="/work/common/lib/vhdl" \
    -e VHDL_LIB_NAMES="$VHDL_LIB_NAMES" \
    -e VHDL_LIB_RELS="$VHDL_LIB_RELS" \
    docker.io/goldensniper/modelsim-docker \
    vsim -c -do /work/common/run.do
fi
