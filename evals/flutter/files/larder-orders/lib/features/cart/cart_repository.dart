import 'package:dio/dio.dart';

import '../../core/errors.dart';
import 'cart.dart';

/// Cart endpoints. Throws NetworkException or ApiException.
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  /// GET /cart.
  Future<Cart> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/cart');
      return Cart.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// POST /cart/items; returns the updated cart.
  Future<Cart> add(String sku, {int quantity = 1}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/cart/items',
        data: {'sku': sku, 'quantity': quantity},
      );
      return Cart.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
