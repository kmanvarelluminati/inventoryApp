import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/features/billing/billing_page.dart';
import 'package:stock_manager/features/items/item_master_page.dart';
import 'package:stock_manager/features/movements/movement_history_page.dart';
import 'package:stock_manager/features/reports/daily_summary_page.dart';
import 'package:stock_manager/features/sales/sales_history_page.dart';
import 'package:stock_manager/features/settings/settings_page.dart';
import 'package:stock_manager/theme/app_theme.dart';

class InventoryBillingApp extends StatefulWidget {
  const InventoryBillingApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<InventoryBillingApp> createState() => _InventoryBillingAppState();
}

class _InventoryBillingAppState extends State<InventoryBillingApp> {
  int _selectedIndex = 0;
  bool _manualPriceOverrideEnabled = false;
  double _gstRatePercent = 0;
  InvoiceProfileSettings _invoiceProfile = const InvoiceProfileSettings(
    shopName: '',
    address: '',
    mobile: '',
    gstNo: '',
    fertiRegnNo: '',
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      widget.database.getManualPriceOverrideEnabled(),
      widget.database.getGstRatePercent(),
      widget.database.getInvoiceProfileSettings(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _manualPriceOverrideEnabled = results[0] as bool;
      _gstRatePercent = results[1] as double;
      _invoiceProfile = results[2] as InvoiceProfileSettings;
    });
  }

  Future<void> _updateManualOverride(bool enabled) async {
    await widget.database.setManualPriceOverrideEnabled(enabled);
    if (!mounted) {
      return;
    }
    setState(() {
      _manualPriceOverrideEnabled = enabled;
    });
  }

  Future<void> _updateGstRatePercent(double ratePercent) async {
    await widget.database.setGstRatePercent(ratePercent);
    if (!mounted) {
      return;
    }
    setState(() {
      _gstRatePercent = ratePercent;
    });
  }

  Future<void> _updateInvoiceProfile(InvoiceProfileSettings settings) async {
    await widget.database.setInvoiceProfileSettings(settings);
    if (!mounted) {
      return;
    }
    setState(() {
      _invoiceProfile = settings;
    });
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return ItemMasterPage(database: widget.database);
      case 1:
        return BillingPage(
          database: widget.database,
          manualPriceOverrideEnabled: _manualPriceOverrideEnabled,
          gstRatePercent: _gstRatePercent,
        );
      case 2:
        return SalesHistoryPage(database: widget.database);
      case 3:
        return MovementHistoryPage(database: widget.database);
      case 4:
        return DailySummaryPage(database: widget.database);
      case 5:
        return SettingsPage(
          manualPriceOverrideEnabled: _manualPriceOverrideEnabled,
          gstRatePercent: _gstRatePercent,
          invoiceProfile: _invoiceProfile,
          onManualPriceOverrideChanged: _updateManualOverride,
          onGstRateChanged: _updateGstRatePercent,
          onInvoiceProfileChanged: _updateInvoiceProfile,
        );
      default:
        return ItemMasterPage(database: widget.database);
    }
  }

  static const _navItems = <_NavItem>[
    _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, label: 'Items'),
    _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Billing'),
    _NavItem(icon: Icons.history, selectedIcon: Icons.history, label: 'Sales'),
    _NavItem(icon: Icons.timeline_outlined, selectedIcon: Icons.timeline, label: 'Movements'),
    _NavItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory and Billing System',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: Row(
          children: [
            // ── Sidebar ──
            Container(
              width: 240,
              color: AppColors.sidebarBg,
              child: Column(
                children: [
                  // Logo / Brand area
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.store_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Stock Manager',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  const SizedBox(height: 8),

                  // Navigation items
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          for (var i = 0; i < _navItems.length; i++)
                            _buildNavItem(i, _navItems[i]),
                          const Spacer(),
                          // Settings at bottom
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Divider(height: 1),
                          ),
                          const SizedBox(height: 4),
                          _buildNavItem(
                            5,
                            const _NavItem(
                              icon: Icons.settings_outlined,
                              selectedIcon: Icons.settings,
                              label: 'Settings',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sidebar right border
            Container(width: 1, color: AppColors.border),

            // ── Main content ──
            Expanded(
              child: Container(
                color: AppColors.pageBg,
                child: _buildPage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.base),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
