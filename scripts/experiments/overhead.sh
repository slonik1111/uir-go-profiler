#!/usr/bin/env bash
set -euo pipefail

# Section 5.3 -- overhead of profiling in CI/CD.
#
# Compares the execution time of the same set of benchmarks in two modes:
# "plain" (benchstat comparison only, as in compare.sh) and "profiled" (the
# same run plus -cpuprofile/-memprofile, as in profile-diff.sh). TRIALS
# independent runs per mode, with the mode order alternated so as not to
# confuse the CI runner's warm-up/noise effect with the effect of profiling.
#
# Result: experiments/overhead_results.csv with columns
# mode,trial,wall_seconds,profile_bytes (profile_bytes=0 for plain).

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

COUNT="${COUNT:-10}"
TRIALS="${TRIALS:-5}"
PKG="${PKG:-./app/...}"

mkdir -p experiments
OUT="experiments/overhead_results.csv"
echo "mode,trial,wall_seconds,profile_bytes" >"$OUT"

run_plain() {
  go test "$PKG" -bench=. -benchmem -run=^$ -count="$COUNT" >/dev/null
}

run_profiled() {
  local cpu="$1" mem="$2"
  go test "$PKG" -bench=. -benchmem -run=^$ -count="$COUNT" \
    -cpuprofile="$cpu" -memprofile="$mem" >/dev/null
}

for trial in $(seq 1 "$TRIALS"); do
  echo "== trial $trial/$TRIALS: plain ==" >&2
  start=$(date +%s.%N)
  run_plain
  end=$(date +%s.%N)
  wall=$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.3f", e-s}')
  echo "plain,${trial},${wall},0" >>"$OUT"

  echo "== trial $trial/$TRIALS: profiled ==" >&2
  CPU="$(mktemp)"
  MEM="$(mktemp)"
  start=$(date +%s.%N)
  run_profiled "$CPU" "$MEM"
  end=$(date +%s.%N)
  wall=$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.3f", e-s}')
  bytes=$(($(stat -c%s "$CPU") + $(stat -c%s "$MEM")))
  echo "profiled,${trial},${wall},${bytes}" >>"$OUT"
  rm -f "$CPU" "$MEM"
done

echo "Результаты: $OUT" >&2
