package app

import (
	"encoding/json"
	"fmt"
	"testing"
)

const benchSize = 1000

func genRecords(n int) []Record {
	records := make([]Record, n)
	for i := range n {
		records[i] = Record{
			ID:       i % (n / 2), // guarantees duplicate IDs for Deduplicate
			Name:     fmt.Sprintf("item-%d", i),
			Category: fmt.Sprintf("cat-%d", i%10),
			Amount:   float64(i) * 1.5,
			Active:   i%3 == 0,
		}
	}
	return records
}

func genJSON(n int) []byte {
	data, err := json.Marshal(genRecords(n))
	if err != nil {
		panic(err)
	}
	return data
}

func BenchmarkParseRecords(b *testing.B) {
	data := genJSON(benchSize)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := ParseRecords(data); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkFilterActive(b *testing.B) {
	records := genRecords(benchSize)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FilterActive(records)
	}
}

func BenchmarkFindByID(b *testing.B) {
	records := genRecords(benchSize)
	missingID := benchSize * 10 // forces a full scan on every call
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FindByID(records, missingID)
	}
}

func BenchmarkAggregate(b *testing.B) {
	records := genRecords(benchSize)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		Aggregate(records)
	}
}

func BenchmarkFormatNames(b *testing.B) {
	records := genRecords(benchSize)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FormatNames(records)
	}
}

func BenchmarkDeduplicate(b *testing.B) {
	records := genRecords(benchSize)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		Deduplicate(records)
	}
}
