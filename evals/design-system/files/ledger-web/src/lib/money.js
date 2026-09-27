export function formatAmount(paise) {
  const rupees = Math.floor(paise / 100);
  return "Rs " + rupees.toLocaleString("en-IN");
}
