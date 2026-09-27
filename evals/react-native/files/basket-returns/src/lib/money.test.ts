import { formatMoney } from './money';

describe('formatMoney', () => {
  it('formats paise as rupees', () => {
    expect(formatMoney(124950, 'INR')).toBe('₹1,249.50');
  });

  it('formats zero', () => {
    expect(formatMoney(0, 'INR')).toBe('₹0.00');
  });
});
