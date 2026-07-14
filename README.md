# uir-go-profiler

Прототип интеграции непрерывного профилирования в CI/CD для раннего обнаружения регрессий производительности (Go).

## Структура

- `app/` — тестовое приложение и бенчмарки (`processor.go`, `processor_test.go`, `bench_test.go`)
- `benchmarks/baseline.txt` — сохранённый эталонный результат `go test -bench`
- `scripts/compare.sh` — сравнение текущего прогона с baseline через `benchstat` и проверка порога регрессии
- `.github/workflows/perf-check.yml` — CI-пайплайн, запускающий бенчмарки на каждый PR
