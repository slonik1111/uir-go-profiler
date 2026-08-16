#!/usr/bin/env bash
set -euo pipefail

# Compares current benchmark results against benchmarks/baseline.txt using
# benchstat, and applies the regression criterion from раздел 2.2:
#   regression  <=>  (Δ metric > THRESHOLD%)  AND  (p < ALPHA)
# See scripts/lib.sh for how the criterion is evaluated.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

THRESHOLD="${THRESHOLD:-10}"   # percent
ALPHA="${ALPHA:-0.05}"
COUNT="${COUNT:-10}"
BASELINE="${BASELINE:-benchmarks/baseline.txt}"
PKG="${PKG:-./app/...}"

command -v benchstat >/dev/null 2>&1 || {
  echo "benchstat not found; install with: go install golang.org/x/perf/cmd/benchstat@latest" >&2
  exit 2
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

CURRENT="$WORKDIR/current.txt"
REPORT_CSV="$WORKDIR/report.csv"

echo "Running benchmarks (count=$COUNT)..." >&2
go test "$PKG" -bench=. -benchmem -run=^$ -count="$COUNT" >"$CURRENT"

echo "Comparing against $BASELINE (alpha=$ALPHA, threshold=${THRESHOLD}%)..." >&2
benchstat -alpha "$ALPHA" -format=csv "$BASELINE" "$CURRENT" >"$REPORT_CSV" 2>"$WORKDIR/warnings.txt" || true

check_regression_csv "$REPORT_CSV" "$THRESHOLD"

echo "## Отчёт сравнения производительности"
echo
echo "Порог: ${THRESHOLD}%, alpha: ${ALPHA}, повторов: ${COUNT}, baseline: ${BASELINE}"
echo
echo "| Метрика | Бенчмарк | Δ | p |"
echo "|---|---|---|---|"
if [[ "$REGRESSED" -eq 1 ]]; then
  printf '%s' "$ROWS"
else
  echo "| — | регрессий выше порога не обнаружено | — | — |"
fi

if [[ -s "$WORKDIR/warnings.txt" ]]; then
  echo >&2
  echo "benchstat warnings:" >&2
  cat "$WORKDIR/warnings.txt" >&2
fi

if [[ "$REGRESSED" -eq 1 ]]; then
  echo "FAIL: обнаружена регрессия производительности" >&2
  exit 1
fi

echo "OK: регрессий не обнаружено" >&2
