package app

import (
	"encoding/json"
	"fmt"
)

// Record is the domain entity processed by every function in this package.
type Record struct {
	ID       int     `json:"id"`
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Amount   float64 `json:"amount"`
	Active   bool    `json:"active"`
}

// ParseRecords decodes a JSON array of records.
func ParseRecords(data []byte) ([]Record, error) {
	var records []Record
	if err := json.Unmarshal(data, &records); err != nil {
		return nil, fmt.Errorf("parse records: %w", err)
	}
	return records, nil
}

// FilterActive returns the subset of records with Active set to true.
func FilterActive(records []Record) []Record {
	active := make([]Record, 0, len(records))
	for _, r := range records {
		if r.Active {
			active = append(active, r)
		}
	}
	return active
}

// FindByID performs a linear scan for a record with the given ID.
func FindByID(records []Record, id int) (Record, bool) {
	for _, r := range records {
		if r.ID == id {
			return r, true
		}
	}
	return Record{}, false
}

// Aggregate sums Amount per Category.
func Aggregate(records []Record) map[string]float64 {
	totals := make(map[string]float64, len(records))
	for _, r := range records {
		totals[r.Category] += r.Amount
	}
	return totals
}

// FormatNames renders each record as a human-readable "name (category): $amount" line.
func FormatNames(records []Record) []string {
	names := make([]string, 0, len(records))
	for _, r := range records {
		names = append(names, fmt.Sprintf("%s (%s): $%.2f", r.Name, r.Category, r.Amount))
	}
	return names
}

// Deduplicate removes records with a repeated ID, keeping the first occurrence.
func Deduplicate(records []Record) []Record {
	result := make([]Record, 0, len(records))
	for i, r := range records {
		duplicate := false
		for j := range i {
			if records[j].ID == r.ID {
				duplicate = true
				break
			}
		}
		if !duplicate {
			result = append(result, r)
		}
	}
	return result
}
