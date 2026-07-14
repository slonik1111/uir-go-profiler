#!/usr/bin/env bash
set -euo pipefail

# Compares current benchmark results against benchmarks/baseline.txt using
# benchstat, and applies the regression criterion from раздел 2.2:
#   regression  <=>  (Δ metric > THRESHOLD%)  AND  (p < ALPHA)
# benchstat itself enforces the p < ALPHA part (it prints "~" instead of a
# percentage when a change isn't significant at ALPHA); this script enforces
# the magnitude threshold on top, and only for increases, since ns/op, B/op
# and allocs/op are all lower-is-better.

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

METRIC=""
REGRESSED=0
ROWS=""

while IFS=, read -r name base_val base_ci cur_val cur_ci vs_base p_col; do
  if [[ "$name" == "" && "$base_val" == "sec/op" ]]; then METRIC="ns/op"; continue; fi
  if [[ "$name" == "" && "$base_val" == "B/op" ]]; then METRIC="B/op"; continue; fi
  if [[ "$name" == "" && "$base_val" == "allocs/op" ]]; then METRIC="allocs/op"; continue; fi
  [[ "$name" == "" || "$name" == "geomean" ]] && continue
  [[ "${vs_base:0:1}" != "+" ]] && continue # "~", "-…%" (improvement) or empty — not a regression

  magnitude="${vs_base#+}"
  magnitude="${magnitude//%/}"

  if awk -v m="$magnitude" -v t="$THRESHOLD" 'BEGIN{exit !(m > t)}'; then
    p_val="${p_col#p=}"
    p_val="${p_val%% *}"
    ROWS="${ROWS}| ${METRIC} | ${name} | ${vs_base} | ${p_val} |"$'\n'
    REGRESSED=1
  fi
done <"$REPORT_CSV"

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
