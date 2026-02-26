import 'package:flutter/material.dart';

import 'package:stock_manager/widgets/desktop_page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.manualPriceOverrideEnabled,
    required this.onManualPriceOverrideChanged,
  });

  final bool manualPriceOverrideEnabled;
  final Future<void> Function(bool enabled) onManualPriceOverrideChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesktopPageHeader(title: 'Settings'),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Allow Manual Price Override in Billing'),
              subtitle: const Text(
                'When disabled, billing always uses item master current price.',
              ),
              value: manualPriceOverrideEnabled,
              onChanged: (value) async {
                await onManualPriceOverrideChanged(value);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings updated.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
