#!/usr/bin/env bash
set -euo pipefail

# Снимает эталонные CPU- и heap-профили (raздел 2.3 / 3.3: профиль как
# артефакт наравне с benchmarks/baseline.txt). Запускается один раз на main
# после каждого осознанного изменения производительности эталона; результат
# коммитится в репозиторий и используется scripts/profile-diff.sh как база
# для сравнения (go tool pprof -diff_base).
#
# Не трогает benchmarks/baseline.txt — тот генерируется/обновляется отдельно,
# чтобы не рассинхронизировать уже посчитанные experiments/*.csv.

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
