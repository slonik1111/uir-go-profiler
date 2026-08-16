package app

import (
	"encoding/json"
	"fmt"
)

// Record — доменная сущность, обрабатываемая всеми функциями пакета.
type Record struct {
	ID       int     `json:"id"`
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Amount   float64 `json:"amount"`
	Active   bool    `json:"active"`
}

// ParseRecords декодирует JSON-массив записей.
func ParseRecords(data []byte) ([]Record, error) {
	var records []Record
	if err := json.Unmarshal(data, &records); err != nil {
		return nil, fmt.Errorf("parse records: %w", err)
	}
	return records, nil
}

// FilterActive возвращает подмножество записей с Active == true.
func FilterActive(records []Record) []Record {
	active := make([]Record, 0, len(records))
	for _, r := range records {
		if r.Active {
			active = append(active, r)
		}
	}
	return active
}

// FindByID выполняет линейный поиск записи по заданному ID.
func FindByID(records []Record, id int) (Record, bool) {
	for _, r := range records {
		if r.ID == id {
			return r, true
		}
	}
	return Record{}, false
}

// Aggregate суммирует Amount по значению Category.
func Aggregate(records []Record) map[string]float64 {
	totals := make(map[string]float64, len(records))
	for _, r := range records {
		totals[r.Category] += r.Amount
	}
	return totals
}

// FormatNames форматирует каждую запись в строку вида "имя (категория): $сумма".
func FormatNames(records []Record) []string {
	names := make([]string, 0, len(records))
	for _, r := range records {
		names = append(names, fmt.Sprintf("%s (%s): $%.2f", r.Name, r.Category, r.Amount))
	}
	return names
}

// Deduplicate удаляет записи с повторяющимся ID, сохраняя первое вхождение.
func Deduplicate(records []Record) []Record {
	seen := make(map[int]struct{}, len(records))
	result := make([]Record, 0, len(records))
	for _, r := range records {
		if _, ok := seen[r.ID]; ok {
			continue
		}
		seen[r.ID] = struct{}{}
		result = append(result, r)
	}
	return result
}
