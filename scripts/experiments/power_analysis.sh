#!/usr/bin/env bash
set -euo pipefail

# Section 5.3 -- minimum detectable regression vs. benchmark repeat count.
#
# For each scenario and each -count value, independently repeats TRIALS
# times: a fresh benchmark run -> benchstat -> threshold check. Independent
# runs are required (not reusing a single file, as in sensitivity.sh),
# because the object under study is precisely how RANDOM noise at different
# repeat counts affects the detection probability.
#
# Result: experiments/power_results.csv with columns
# scenario,count,trial,detected. The default parameters are small (this is
# a demo run) -- for a real study, increase TRIALS and COUNTS (each extra
# run costs time: count is proportional to the time of a single
# go test -bench).

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
ALPHA="${ALPHA:-0.05}"
THRESHOLD="${THRESHOLD:-10}"
TRIALS="${TRIALS:-5}"
COUNTS=(${COUNTS:-3 5 10 20})
SCENARIOS=(${SCENARIOS:-main regression/quadratic-dedup})

command -v benchstat >/dev/null 2>&1 || {
  echo "benchstat not found; install with: go install golang.org/x/perf/cmd/benchstat@latest" >&2
  exit 2
}

mkdir -p experiments
FINAL_OUT="experiments/power_results.csv"
# Write to a temp file OUTSIDE the working tree: FINAL_OUT is tracked by
# git, and writing to it between git checkouts would make the checkout
# fail ("local changes would be overwritten") on the very second scenario.
OUT="$(mktemp)"
echo "scenario,count,trial,detected" >"$OUT"

ORIG_BRANCH="$(git branch --show-current)"
trap 'git checkout -q "$ORIG_BRANCH" 2>/dev/null || true; rm -f "$OUT" "$BASELINE_COPY"' EXIT

for scenario in "${SCENARIOS[@]}"; do
  git checkout -q "$scenario"

  for count in "${COUNTS[@]}"; do
    for trial in $(seq 1 "$TRIALS"); do
      echo "== $scenario: count=$count trial=$trial/$TRIALS ==" >&2
      CURRENT="$(mktemp)"
      go test ./app/... -bench=. -benchmem -run=^$ -count="$count" >"$CURRENT" 2>&1

      CSV="$(mktemp)"
      benchstat -alpha "$ALPHA" -format=csv "$BASELINE" "$CURRENT" >"$CSV" 2>/dev/null || true

      check_regression_csv "$CSV" "$THRESHOLD"
      echo "${scenario//\//_},${count},${trial},${REGRESSED}" >>"$OUT"

      rm -f "$CURRENT" "$CSV"
    done
  done
done

git checkout -q "$ORIG_BRANCH"
cp "$OUT" "$FINAL_OUT"

echo "Результаты: $FINAL_OUT" >&2
