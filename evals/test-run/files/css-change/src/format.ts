export const rupees = (paise: number): string => `Rs ${(paise / 100).toFixed(2)}`;
