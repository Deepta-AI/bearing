// Package gst computes GST on invoice lines.
package gst

// Tax returns the GST in paise on amountPaise at rateBps basis points.
func Tax(amountPaise, rateBps int64) int64 {
	return amountPaise * rateBps / 10000
}

// Split divides a GST amount into CGST and SGST halves for an intra-state
// supply. An odd paisa goes to CGST.
func Split(taxPaise int64) (cgst, sgst int64) {
	sgst = taxPaise / 2
	return taxPaise - sgst, sgst
}
