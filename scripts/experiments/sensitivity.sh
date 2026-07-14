#!/usr/bin/env bash
set -euo pipefail

# Раздел 5.2 — чувствительность порога обнаружения.
#
# Для каждого сценария (main = фоновый шум без изменений, плюс 4 ветки
# regression/*) собирает ОДИН прогон бенчмарков, а затем прогоняет через него
# все комбинации alpha x threshold (benchstat по CSV — дёшево, повторный
# go test не нужен). Результат: experiments/sensitivity_results.csv со
# столбцами scenario,alpha,threshold,detected — на main "detected=1" это
# ложное срабатывание, на regression/* — успешное обнаружение.

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
source scripts/lib.sh

BASELINE="${BASELINE:-benchmarks/baseline.txt}"
COUNT="${COUNT:-10}"
ALPHAS=(${ALPHAS:-0.01 0.05 0.10})
THRESHOLDS=(${THRESHOLDS:-5 10 15 20 30 50})
SCENARIOS=(${SCENARIOS:-main regression/extra-allocation regression/quadratic-dedup regression/latency regression/memory-growth})

command -v benchstat >/dev/null 2>&1 || {
  echo "benchstat not found; install with: go install golang.org/x/perf/cmd/benchstat@latest" >&2
  exit 2
}

mkdir -p experiments
OUT="experiments/sensitivity_results.csv"
echo "scenario,alpha,threshold,detected" >"$OUT"

ORIG_BRANCH="$(git branch --show-current)"
trap 'git checkout -q "$ORIG_BRANCH"' EXIT

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

echo "Результаты: $OUT" >&2
