import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http.dart';

/// Lets the user turn order update notifications on or off.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    ref
        .read(dioProvider)
        .get<Map<String, dynamic>>('/me/notification-settings')
        .then((res) {
          setState(() => _enabled = res.data!['order_updates'] as bool);
        })
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _enabled == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Order updates'),
                  subtitle: const Text('Packed, out for delivery, delivered'),
                  value: _enabled!,
                  onChanged: (value) {
                    setState(() => _enabled = value);
                    ref.read(dioProvider).put<void>(
                      '/me/notification-settings',
                      data: {'order_updates': value},
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.info_outline, size: 18),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(
                          content: Text(
                            'We only send updates about your own orders.',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
