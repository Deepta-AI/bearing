import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Formats an amount in minor units (paise for INR) with its currency,
/// for example formatMoney(125099, 'INR') is "₹1,250.99".
String formatMoney(int minor, String currency, {String locale = 'en_IN'}) {
  final format = NumberFormat.simpleCurrency(locale: locale, name: currency);
  final digits = format.decimalDigits ?? 2;
  return format.format(minor / math.pow(10, digits));
}
