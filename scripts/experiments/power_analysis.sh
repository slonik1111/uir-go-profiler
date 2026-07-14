#!/usr/bin/env bash
set -euo pipefail

# Раздел 5.3 — минимально обнаружимая регрессия vs число повторов бенчмарка.
#
# Для каждого сценария и каждого значения -count независимо повторяет TRIALS
# раз: свежий прогон бенчмарков -> benchstat -> проверка порога. Нужны именно
# независимые прогоны (не переиспользование одного файла, как в
# sensitivity.sh), потому что сам объект изучения — это то, как СЛУЧАЙНЫЙ шум
# при разном числе повторов влияет на вероятность обнаружения.
#
# Результат: experiments/power_results.csv со столбцами
# scenario,count,trial,detected. По умолчанию параметры маленькие (это
# демо-прогон) — для реального исследования увеличьте TRIALS и COUNTS
# (каждый дополнительный прогон стоит времени: count пропорционален времени
# одного go test -bench).

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
source scripts/lib.sh

BASELINE="${BASELINE:-benchmarks/baseline.txt}"
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
OUT="experiments/power_results.csv"
echo "scenario,count,trial,detected" >"$OUT"

ORIG_BRANCH="$(git branch --show-current)"
trap 'git checkout -q "$ORIG_BRANCH"' EXIT

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

echo "Результаты: $OUT" >&2
