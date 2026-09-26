import 'package:freezed_annotation/freezed_annotation.dart';

part 'health.freezed.dart';
part 'health.g.dart';

/// The API's /healthz answer. Generated code comes from `make gen`.
@freezed
abstract class Health with _$Health {
  const factory Health({required String status, String? version}) = _Health;

  factory Health.fromJson(Map<String, dynamic> json) => _$HealthFromJson(json);
}
