import 'package:app/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats paise as rupees with grouping', () {
    expect(formatMoney(125099, 'INR'), '₹1,250.99');
  });

  test('formats zero', () {
    expect(formatMoney(0, 'INR'), '₹0.00');
  });
}
