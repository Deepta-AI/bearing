import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart.freezed.dart';
part 'cart.g.dart';

/// One line of the cart.
@freezed
abstract class CartLine with _$CartLine {
  const factory CartLine({
    required String sku,
    required String name,
    required int quantity,
    @JsonKey(name: 'unit_price_minor') required int unitPriceMinor,
  }) = _CartLine;

  factory CartLine.fromJson(Map<String, dynamic> json) =>
      _$CartLineFromJson(json);
}

/// The signed-in user's cart.
@freezed
abstract class Cart with _$Cart {
  const Cart._();

  const factory Cart({
    required String currency,
    required List<CartLine> items,
  }) = _Cart;

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);

  /// Sum of quantity times unit price, in minor units.
  int get totalMinor =>
      items.fold(0, (sum, line) => sum + line.quantity * line.unitPriceMinor);
}
