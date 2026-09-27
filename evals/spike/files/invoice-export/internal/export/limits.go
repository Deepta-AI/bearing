package export

// MaxExportRows caps one export. Raised for the Enterprise plan, whose
// largest tenants issue about 20,000 invoices a month and export a year.
const MaxExportRows = 250_000
