package app

import (
	"reflect"
	"testing"
)

func sampleRecords() []Record {
	return []Record{
		{ID: 1, Name: "Alpha", Category: "food", Amount: 10, Active: true},
		{ID: 2, Name: "Beta", Category: "travel", Amount: 20, Active: false},
		{ID: 3, Name: "Gamma", Category: "food", Amount: 5, Active: true},
		{ID: 1, Name: "Alpha", Category: "food", Amount: 10, Active: true}, // duplicate ID
	}
}

func TestParseRecords(t *testing.T) {
	cases := []struct {
		name    string
		input   string
		want    []Record
		wantErr bool
	}{
		{
			name:  "valid array",
			input: `[{"id":1,"name":"Alpha","category":"food","amount":10,"active":true}]`,
			want:  []Record{{ID: 1, Name: "Alpha", Category: "food", Amount: 10, Active: true}},
		},
		{name: "empty array", input: `[]`, want: []Record{}},
		{name: "malformed json", input: `not json`, wantErr: true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := ParseRecords([]byte(tc.input))
			if (err != nil) != tc.wantErr {
				t.Fatalf("ParseRecords() error = %v, wantErr %v", err, tc.wantErr)
			}
			if tc.wantErr {
				return
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("ParseRecords() = %#v, want %#v", got, tc.want)
			}
		})
	}
}

func TestFilterActive(t *testing.T) {
	got := FilterActive(sampleRecords())
	if len(got) != 3 {
		t.Fatalf("got %d active records, want 3", len(got))
	}
	for _, r := range got {
		if !r.Active {
			t.Fatalf("FilterActive returned inactive record: %#v", r)
		}
	}
}

func TestFilterActive_Empty(t *testing.T) {
	got := FilterActive(nil)
	if len(got) != 0 {
		t.Fatalf("got %d records, want 0", len(got))
	}
}

func TestFindByID(t *testing.T) {
	records := sampleRecords()

	if r, ok := FindByID(records, 2); !ok || r.Name != "Beta" {
		t.Fatalf("FindByID(2) = %#v, %v; want Beta, true", r, ok)
	}
	if _, ok := FindByID(records, 999); ok {
		t.Fatalf("FindByID(999) found a record that should not exist")
	}
}

func TestAggregate(t *testing.T) {
	got := Aggregate(sampleRecords())
	want := map[string]float64{"food": 25, "travel": 20}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Aggregate() = %#v, want %#v", got, want)
	}
}

func TestFormatNames(t *testing.T) {
	got := FormatNames([]Record{{Name: "Alpha", Category: "food", Amount: 10}})
	want := []string{"Alpha (food): $10.00"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("FormatNames() = %#v, want %#v", got, want)
	}
}

func TestDeduplicate(t *testing.T) {
	got := Deduplicate(sampleRecords())
	if len(got) != 3 {
		t.Fatalf("got %d records after dedup, want 3", len(got))
	}
	seen := map[int]bool{}
	for _, r := range got {
		if seen[r.ID] {
			t.Fatalf("Deduplicate left a repeated ID: %d", r.ID)
		}
		seen[r.ID] = true
	}
}
