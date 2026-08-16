#!/usr/bin/env bash
set -euo pipefail

# Captures the baseline CPU and heap profiles (Section 2.3 / 3.3: a profile
# as an artifact alongside benchmarks/baseline.txt). Run once on main after
# any deliberate change to the baseline's performance; the result is
# committed to the repository and used by scripts/profile-diff.sh as the
# reference for comparison (go tool pprof -diff_base).
#
# Does not touch benchmarks/baseline.txt -- that one is generated/updated
# separately, to avoid desynchronizing the already-computed experiments/*.csv.

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

COUNT="${COUNT:-10}"
PKG="${PKG:-./app/...}"
OUTDIR="${OUTDIR:-benchmarks}"

mkdir -p "$OUTDIR"

echo "Running benchmarks with profiling (count=$COUNT)..." >&2
go test "$PKG" -bench=. -benchmem -run=^$ -count="$COUNT" \
  -cpuprofile="$OUTDIR/baseline-cpu.pprof" \
  -memprofile="$OUTDIR/baseline-mem.pprof" >/dev/null

echo "Wrote $OUTDIR/baseline-cpu.pprof and $OUTDIR/baseline-mem.pprof" >&2
