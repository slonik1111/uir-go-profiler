# uir-go-profiler

Прототип интеграции непрерывного профилирования в CI/CD для раннего обнаружения регрессий производительности (Go).

## Структура

- `app/` — тестовое приложение и бенчмарки (`processor.go`, `processor_test.go`, `bench_test.go`)
- `benchmarks/baseline.txt` — сохранённый эталонный результат `go test -bench -count=10`
- `benchmarks/baseline-cpu.pprof`, `benchmarks/baseline-mem.pprof` — эталонные CPU/heap pprof-профили того же прогона
- `scripts/lib.sh` — общая логика разбора CSV-отчёта `benchstat` и применения критерия регрессии
- `scripts/compare.sh` — сравнение текущего прогона с baseline по агрегированным метрикам (ns/op, B/op, allocs/op), используется локально и в CI
- `scripts/capture-baseline-profiles.sh` — (пере)генерирует `benchmarks/baseline-{cpu,mem}.pprof`
- `scripts/profile-diff.sh` — непрерывное профилирование в узком смысле: снимает текущие CPU/heap pprof-профили и сравнивает их с эталонными через `go tool pprof -diff_base`, показывая, какие функции стали "тяжелее"; используется локально и в CI
- `scripts/experiments/sensitivity.sh` — раздел 5.2: чувствительность порога/alpha на 4 сценариях регрессий + шуме
- `scripts/experiments/power_analysis.sh` — раздел 5.2: вероятность обнаружения regression vs число повторов (`-count`)
- `scripts/experiments/overhead.sh` — раздел 5.3: накладные расходы профилирования в CI/CD (время `go test` с `-cpuprofile/-memprofile` и без)
- `.github/workflows/perf-check.yml` — CI-пайплайн: `compare.sh` (сравнение метрик) + `profile-diff.sh` (сравнение профилей, профили выгружаются как build-артефакт) на каждый PR
- ветки `regression/*` — 4 сценария регрессий для раздела 5.1 (каждая — один точечный diff от `main`)

## Установка

```sh
go install golang.org/x/perf/cmd/benchstat@latest
export PATH="$PATH:$(go env GOPATH)/bin"
```

## Использование

```sh
go test ./...                      # unit-тесты
go test ./app/... -bench=. -benchmem   # бенчмарки разово
./scripts/compare.sh                # сравнение с baseline (THRESHOLD/ALPHA/COUNT — env-переменные)
./scripts/profile-diff.sh           # снять CPU/heap pprof-профиль и сравнить с baseline-*.pprof
```

Сценарии регрессий — отдельные git-ветки от `main`:

| Ветка | Что меняет |
|---|---|
| `regression/extra-allocation` | убирает capacity hint в `FilterActive` |
| `regression/quadratic-dedup` | заменяет map на вложенный цикл в `Deduplicate` (O(n)→O(n²)) |
| `regression/latency` | добавляет `time.Sleep` в `FindByID` |
| `regression/memory-growth` | добавляет никогда не очищаемый кэш в `Aggregate` |

```sh
git checkout regression/quadratic-dedup && ./scripts/compare.sh   # должно упасть
git checkout main
```

Эксперименты (раздел 5.2–5.3, результаты пишутся в `experiments/*.csv`):

```sh
./scripts/experiments/sensitivity.sh                              # раздел 5.2, полный прогон, ~5 бенчмарк-сетов
TRIALS=20 COUNTS="3 5 10 20 50" ./scripts/experiments/power_analysis.sh   # раздел 5.2, полный масштаб — долго, ждать
COUNT=10 TRIALS=10 ./scripts/experiments/overhead.sh              # раздел 5.3, ~15-20 мин на полный масштаб
```

По умолчанию `power_analysis.sh` и `overhead.sh` используют уменьшённые `TRIALS`/`COUNTS` для быстрой проверки — перед тем как писать соответствующий раздел, перезапустите с большими значениями.
