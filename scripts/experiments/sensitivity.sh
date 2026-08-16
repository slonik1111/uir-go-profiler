#!/usr/bin/env bash
set -euo pipefail

# Section 5.2 -- sensitivity of the detection threshold.
#
# For each scenario (main = background noise with no changes, plus the 4
# regression/* branches) collects ONE run of benchmarks, then runs it
# through every combination of alpha x threshold (benchstat via CSV is
# cheap, no need to repeat go test). Result: experiments/sensitivity_results.csv
# with columns scenario,alpha,threshold,detected -- on main "detected=1" is
# a false positive, on regression/* it is a successful detection.

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
source scripts/lib.sh

BASELINE="${BASELINE:-benchmarks/baseline.txt}"
# Copy OUTSIDE the working tree: baseline.txt is tracked by git and could
# in principle differ between branches (even if it doesn't right now) --
# without this, a scenario's git checkout would silently swap in ITS OWN
# baseline.txt instead of the fixed reference captured once on main.
BASELINE_COPY="$(mktemp)"
cp "$BASELINE" "$BASELINE_COPY"
BASELINE="$BASELINE_COPY"
COUNT="${COUNT:-10}"
ALPHAS=(${ALPHAS:-0.01 0.05 0.10})
THRESHOLDS=(${THRESHOLDS:-5 10 15 20 30 50})
SCENARIOS=(${SCENARIOS:-main regression/extra-allocation regression/quadratic-dedup regression/latency regression/memory-growth})

command -v benchstat >/dev/null 2>&1 || {
  echo "benchstat not found; install with: go install golang.org/x/perf/cmd/benchstat@latest" >&2
  exit 2
}

mkdir -p experiments
FINAL_OUT="experiments/sensitivity_results.csv"
# Write to a temp file OUTSIDE the working tree: FINAL_OUT is tracked by
# git, and writing to it between git checkouts would make the checkout
# fail ("local changes would be overwritten") on the very second scenario.
OUT="$(mktemp)"
echo "scenario,alpha,threshold,detected" >"$OUT"

ORIG_BRANCH="$(git branch --show-current)"
trap 'git checkout -q "$ORIG_BRANCH" 2>/dev/null || true; rm -f "$OUT" "$BASELINE_COPY"' EXIT

for scenario in "${SCENARIOS[@]}"; do
  echo "== $scenario: running benchmarks (count=$COUNT) ==" >&2
  git checkout -q "$scenario"

  CURRENT="$(mktemp)"
  go test ./app/... -bench=. -benchmem -run=^$ -count="$COUNT" >"$CURRENT" 2>&1

  for alpha in "${ALPHAS[@]}"; do
    CSV="$(mktemp)"
    benchstat -alpha "$alpha" -format=csv "$BASELINE" "$CURRENT" >"$CSV" 2>/dev/null || true

    for threshold in "${THRESHOLDS[@]}"; do
      check_regression_csv "$CSV" "$threshold"
      echo "${scenario//\//_},${alpha},${threshold},${REGRESSED}" >>"$OUT"
    done
    rm -f "$CSV"
  done
  rm -f "$CURRENT"
done

git checkout -q "$ORIG_BRANCH"
cp "$OUT" "$FINAL_OUT"

echo "Результаты: $FINAL_OUT" >&2
