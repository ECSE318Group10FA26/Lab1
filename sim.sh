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
# TB_SOURCE and TB_TOP (see problem1/problem.env for a template).
# LIB_DIRS is optional: each directory's *.v files are appended to SOURCES.
# Output (work/, transcript.log, VCD) lands inside the problem directory.
set -euo pipefail
shopt -s globstar # let LIB_DIRS' **/*.v glob recurse into subdirectories

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

# at least one of SOURCES / LIB_DIRS must provide design sources
if [ -z "${SOURCES:-}" ] && [ -z "${LIB_DIRS:-}" ]; then
  echo "error: problem.env must define SOURCES or LIB_DIRS" >&2
  exit 1
fi
: "${TB_SOURCE:?problem.env must define TB_SOURCE}"
: "${TB_TOP:?problem.env must define TB_TOP}"

# expand optional library directories: each directory's *.v files are
# appended to SOURCES (alphabetical order within a directory)
for d in ${LIB_DIRS:-}; do
  if [ ! -d "$PROBLEM_DIR/$d" ]; then
    echo "error: library directory '$d' (from LIB_DIRS) not found in $PROBLEM_DIR" >&2
    exit 1
  fi
  for g in "$PROBLEM_DIR/$d"/**/*.v; do
    [ -e "$g" ] || continue # directory has no .v files
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
  echo "==> simulating ${PROBLEM_NAME:-$REL} (local vsim)"
  # run from the problem dir so the relative paths in problem.env resolve,
  # mirroring the container's working directory
  (
    cd "$PROBLEM_DIR"
    export SOURCES="${SOURCES:-}" TB_SOURCE TB_TOP
    vsim -c -do "$REPO_ROOT/common/run.do"
  )
else
  echo "==> simulating ${PROBLEM_NAME:-$REL}"
  podman run --rm \
    -v "$REPO_ROOT:/work:Z" \
    -w "/work/$REL" \
    -e SOURCES="$SOURCES" \
    -e TB_SOURCE="$TB_SOURCE" \
    -e TB_TOP="$TB_TOP" \
    docker.io/goldensniper/modelsim-docker \
    vsim -c -do /work/common/run.do
fi
