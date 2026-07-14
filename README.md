# uir-go-profiler

Прототип интеграции непрерывного профилирования в CI/CD для раннего обнаружения регрессий производительности (Go).

## Структура

- `app/` — тестовое приложение и бенчмарки (`processor.go`, `processor_test.go`, `bench_test.go`)
- `benchmarks/baseline.txt` — сохранённый эталонный результат `go test -bench -count=10`
- `scripts/lib.sh` — общая логика разбора CSV-отчёта `benchstat` и применения критерия регрессии
- `scripts/compare.sh` — сравнение текущего прогона с baseline, используется локально и в CI
- `scripts/experiments/sensitivity.sh` — раздел 5.2: чувствительность порога/alpha на 4 сценариях регрессий + шуме
- `scripts/experiments/power_analysis.sh` — раздел 5.3: вероятность обнаружения regression vs число повторов (`-count`)
- `.github/workflows/perf-check.yml` — CI-пайплайн, запускающий бенчмарки и `compare.sh` на каждый PR
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
./scripts/experiments/sensitivity.sh                              # полный прогон, ~5 бенчмарк-сетов
TRIALS=20 COUNTS="3 5 10 20 50" ./scripts/experiments/power_analysis.sh   # полный масштаб — долго, ждать
```

По умолчанию `power_analysis.sh` использует уменьшённые `TRIALS`/`COUNTS` для быстрой проверки — перед тем как писать раздел 5.3, перезапустите с большими значениями.
