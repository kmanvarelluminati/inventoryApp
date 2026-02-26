import 'package:flutter/material.dart';

import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/features/billing/billing_page.dart';
import 'package:stock_manager/features/items/item_master_page.dart';
import 'package:stock_manager/features/movements/movement_history_page.dart';
import 'package:stock_manager/features/reports/daily_summary_page.dart';
import 'package:stock_manager/features/sales/sales_history_page.dart';
import 'package:stock_manager/features/settings/settings_page.dart';

class InventoryBillingApp extends StatefulWidget {
  const InventoryBillingApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<InventoryBillingApp> createState() => _InventoryBillingAppState();
}

class _InventoryBillingAppState extends State<InventoryBillingApp> {
  int _selectedIndex = 0;
  bool _manualPriceOverrideEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await widget.database.getManualPriceOverrideEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _manualPriceOverrideEnabled = enabled;
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

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return ItemMasterPage(database: widget.database);
      case 1:
        return BillingPage(
          database: widget.database,
          manualPriceOverrideEnabled: _manualPriceOverrideEnabled,
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
          onManualPriceOverrideChanged: _updateManualOverride,
        );
      default:
        return ItemMasterPage(database: widget.database);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory and Billing System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Row(
          children: [
            Container(
              width: 240,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: NavigationRail(
                selectedIndex: _selectedIndex,
                extended: true,
                minExtendedWidth: 240,
                onDestinationSelected: (value) {
                  setState(() {
                    _selectedIndex = value;
                  });
                },
                labelType: NavigationRailLabelType.none,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    label: Text('Items'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    label: Text('Billing'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history),
                    label: Text('Sales'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.timeline_outlined),
                    label: Text('Movements'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.summarize_outlined),
                    label: Text('Reports'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: Text('Settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(children: [Expanded(child: _buildPage())]),
            ),
          ],
        ),
      ),
    );
  }
}
