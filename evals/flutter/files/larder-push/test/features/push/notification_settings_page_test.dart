import 'package:app/core/http.dart';
import 'package:app/features/push/notification_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_adapter.dart';

void main() {
  testWidgets('shows the order updates switch', (tester) async {
    final adapter = FakeAdapter()
      ..on('GET', '/me/notification-settings',
          const FakeReply(200, {'order_updates': true}));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(testDio(adapter))],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byType(Switch), findsOneWidget);
  });
}
