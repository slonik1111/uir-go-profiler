#!/usr/bin/env bash
set -euo pipefail

# Непрерывное профилирование в узком смысле: снимает CPU- и heap-профили
# текущего дерева (go test -cpuprofile/-memprofile, т.е. настоящие
# pprof-сэмплы, а не только агрегированные ns/op из benchstat) и сравнивает
# их с эталонными профилями через `go tool pprof -diff_base`. Показывает,
# КАКИЕ функции стали "тяжелее" и на сколько — то, чего benchstat в принципе
# не может дать, так как он видит только суммарное время/аллокации бенчмарка
# целиком, а не разбивку по функциям вызова.

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

COUNT="${COUNT:-10}"
PKG="${PKG:-./app/...}"
BASE_CPU="${BASE_CPU:-benchmarks/baseline-cpu.pprof}"
BASE_MEM="${BASE_MEM:-benchmarks/baseline-mem.pprof}"
TOPN="${TOPN:-10}"

# CUR_DIR: if unset, current profiles go to a scratch dir removed on exit
# (interactive/local use). CI passes a stable path so a later workflow step
# can upload the raw profiles as an artifact (go tool pprof -http needs the
# files, not just this text diff).
if [[ -n "${CUR_DIR:-}" ]]; then
  WORKDIR="$CUR_DIR"
  mkdir -p "$WORKDIR"
else
  WORKDIR="$(mktemp -d)"
  trap 'rm -rf "$WORKDIR"' EXIT
fi

CUR_CPU="$WORKDIR/current-cpu.pprof"
CUR_MEM="$WORKDIR/current-mem.pprof"

echo "Running benchmarks with profiling (count=$COUNT)..." >&2
go test "$PKG" -bench=. -benchmem -run=^$ -count="$COUNT" \
  -cpuprofile="$CUR_CPU" -memprofile="$CUR_MEM" >/dev/null

echo "## Профиль CPU: top-$TOPN функций по cumulative time"
echo
if [[ -f "$BASE_CPU" ]]; then
  echo '```'
  go tool pprof -top -diff_base="$BASE_CPU" -nodecount="$TOPN" "$CUR_CPU" 2>/dev/null || true
  echo '```'
else
  echo "(эталонный профиль $BASE_CPU не найден — показываю профиль без diff)" >&2
  echo '```'
  go tool pprof -top -nodecount="$TOPN" "$CUR_CPU" 2>/dev/null || true
  echo '```'
fi

echo
echo "## Профиль памяти (alloc_space): top-$TOPN функций по cumulative allocation"
echo
if [[ -f "$BASE_MEM" ]]; then
  echo '```'
  go tool pprof -top -alloc_space -diff_base="$BASE_MEM" -nodecount="$TOPN" "$CUR_MEM" 2>/dev/null || true
  echo '```'
else
  echo "(эталонный профиль $BASE_MEM не найден — показываю профиль без diff)" >&2
  echo '```'
  go tool pprof -top -alloc_space -nodecount="$TOPN" "$CUR_MEM" 2>/dev/null || true
  echo '```'
fi
