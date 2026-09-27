// Display formatting for the dashboard figures. Every figure on screen goes
// through formatStat so the cards, the export and the tests agree.

const currency = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" });
const integer = new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 });
const percent = new Intl.NumberFormat("en-IN", { style: "percent", maximumFractionDigits: 1 });

const KINDS = {
  revenue: "currency",
  orders: "integer",
  conversion: "percent",
  refundRate: "percent",
};

export function kindOf(stat) {
  return KINDS[stat];
}

export function formatStat(stat, value) {
  if (value === null || value === undefined || Number.isNaN(value)) return "n/a";
  switch (KINDS[stat]) {
    case "currency": return currency.format(value);
    case "integer": return integer.format(value);
    case "percent": return percent.format(value);
    default: throw new Error(`unknown stat ${stat}`);
  }
}
