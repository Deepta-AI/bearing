package route

import (
	"errors"
	"testing"
)

func TestETAMinutes(t *testing.T) {
	cases := []struct {
		name        string
		dist, stops int
		want        int
	}{
		{"zero", 0, 0, 0},
		{"rounds up", 401, 0, 2},
		{"with stops", 4000, 3, 22},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := ETAMinutes(c.dist, c.stops)
			if err != nil || got != c.want {
				t.Fatalf("ETAMinutes(%d, %d) = %d, %v; want %d", c.dist, c.stops, got, err, c.want)
			}
		})
	}
}

func TestETAMinutesRejectsNegative(t *testing.T) {
	if _, err := ETAMinutes(-1, 0); !errors.Is(err, ErrInvalid) {
		t.Fatalf("want ErrInvalid, got %v", err)
	}
}
