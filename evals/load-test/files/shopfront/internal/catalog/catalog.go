// Package catalog holds the product list the storefront searches.
package catalog

import "fmt"

type Product struct {
	SKU        string `json:"sku"`
	Name       string `json:"name"`
	PricePaise int64  `json:"price_paise"`
	Summary    string `json:"summary"`
}

// Seed returns the catalogue the service boots with.
func Seed() []Product {
	kinds := []string{"running shoes", "trail shoes", "sandals", "socks", "rain jacket", "t-shirt", "shorts", "cap", "backpack", "water bottle"}
	about := map[string]string{
		"running shoes": "Light road shoe with a cushioned foam midsole, breathable engineered mesh upper and a rubber outsole that grips on wet tarmac. Fits true to size; half sizes available.",
		"trail shoes":   "Trail shoe with a rock plate, 5 mm lugs and a gusseted tongue that keeps grit out. Stiffer than our road shoes; pick half a size up for long descents.",
		"sandals":       "Adjustable strap sandal with a contoured footbed, quick-dry webbing and a soft heel pad. Rinse after sea water; do not machine wash.",
		"socks":         "Pack of three merino blend socks with a padded heel and toe, arch support band and seamless toe closure. Machine wash cold, dry flat.",
		"rain jacket":   "Packable rain jacket with taped seams, a 10,000 mm waterproof rating, adjustable hood and two zipped hand pockets. Packs into its own chest pocket.",
		"t-shirt":       "Technical t-shirt in a recycled polyester knit that wicks sweat and dries fast, with flat seams and a reflective logo on the back.",
		"shorts":        "Running shorts with a 5 inch inseam, brief liner, zipped back pocket for keys and a phone pocket on each side of the waistband.",
		"cap":           "Lightweight running cap with a perforated crown, sweat band, adjustable back strap and a curved peak that folds for packing.",
		"backpack":      "20 litre day pack with a padded laptop sleeve, hip belt, hydration port and a rain cover that stows in the base.",
		"water bottle":  "750 ml insulated steel bottle that keeps drinks cold for 24 hours, with a leak-proof lid and a loop that clips to a bag.",
	}
	colours := []string{"black", "white", "red", "blue", "green", "grey", "navy", "orange"}
	var out []Product
	n := 0
	for _, k := range kinds {
		for _, c := range colours {
			n++
			out = append(out, Product{SKU: fmt.Sprintf("SKU-%04d", n), Name: c + " " + k, PricePaise: int64(49900 + n*1000), Summary: about[k] + " Shown in " + c + "; the colour can vary slightly between dye batches. Free delivery on orders over Rs 999 and free returns within 30 days if unused and in the original packaging."})
		}
	}
	return out
}
