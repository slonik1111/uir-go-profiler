#!/usr/bin/env bash
set -euo pipefail

# Раздел 5.3 — накладные расходы профилирования в CI/CD.
#
# Сравнивает время выполнения одного и того же набора бенчмарков в двух
# режимах: "plain" (только benchstat-сравнение, как в compare.sh) и
# "profiled" (тот же прогон плюс -cpuprofile/-memprofile, как в
# profile-diff.sh). TRIALS независимых прогонов на каждый режим, порядок
# режимов чередуется, чтобы не путать эффект прогрева/шума CI-раннера с
# эффектом профилирования.
#
# Результат: experiments/overhead_results.csv со столбцами
# mode,trial,wall_seconds,profile_bytes (profile_bytes=0 для plain).

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
