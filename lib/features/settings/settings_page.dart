import 'package:flutter/material.dart';

import 'package:stock_manager/theme/app_theme.dart';
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesktopPageHeader(
            title: 'Settings',
            subtitle: 'Configure application preferences',
          ),
          const SizedBox(height: 24),

          // Billing section
          const Text(
            'BILLING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: manualPriceOverrideEnabled
                          ? AppColors.primaryLight
                          : AppColors.tableHeaderBg,
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: Icon(
                      Icons.price_change_outlined,
                      size: 18,
                      color: manualPriceOverrideEnabled
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Allow Manual Price Override',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'When disabled, billing always uses the item master current price.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: manualPriceOverrideEnabled,
                    activeTrackColor: AppColors.primaryLight,
                    activeThumbColor: AppColors.primary,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
