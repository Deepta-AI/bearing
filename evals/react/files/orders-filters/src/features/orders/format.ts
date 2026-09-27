const rupees = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" });
const dateTime = new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" });

export const formatPaise = (paise: number) => rupees.format(paise / 100);
export const formatPlacedAt = (iso: string) => dateTime.format(new Date(iso));
