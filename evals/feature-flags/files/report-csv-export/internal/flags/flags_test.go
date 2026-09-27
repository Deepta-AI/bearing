package flags

import "testing"

func TestMissingValueIsOff(t *testing.T) {
	s := Load(func(string) string { return "" })
	for _, f := range All {
		if s.Enabled(f) {
			t.Errorf("%s is on with no value", f)
		}
	}
}

func TestTrueIsOn(t *testing.T) {
	s := Load(func(k string) string {
		if k == "FLAG_SAVED_FILTERS" {
			return "true"
		}
		return ""
	})
	if !s.Enabled(SavedFilters) {
		t.Error("saved_filters should be on")
	}
	if s.Enabled(AuditLogV2) {
		t.Error("audit_log_v2 should be off")
	}
}
