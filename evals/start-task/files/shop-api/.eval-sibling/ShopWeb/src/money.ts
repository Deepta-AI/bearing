// Amounts arrive from ShopApi as integer paise.
export function rupees(paise: number): string {
  return (paise / 100).toFixed(2);
}
