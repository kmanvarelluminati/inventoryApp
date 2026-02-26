import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/theme/app_theme.dart';
import 'package:stock_manager/utils/formatters.dart';
import 'package:stock_manager/widgets/desktop_page_header.dart';

class MovementHistoryPage extends StatefulWidget {
  const MovementHistoryPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<MovementHistoryPage> createState() => _MovementHistoryPageState();
}

class _MovementHistoryPageState extends State<MovementHistoryPage> {
  bool _loading = true;
  int? _filterItemId;
  List<ItemRecord> _items = const [];
  List<StockMovementRecord> _movements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final items = await widget.database.getItems();
    final movements = await widget.database.getStockMovements(
      itemId: _filterItemId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _movements = movements;
      _loading = false;
    });
  }

  Color _actionColor(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('sale')) return AppColors.danger;
    if (lower.contains('add') || lower.contains('open')) return AppColors.success;
    if (lower.contains('cancel')) return AppColors.warning;
    return AppColors.info;
  }

  Color _actionBgColor(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('sale')) return AppColors.dangerBg;
    if (lower.contains('add') || lower.contains('open')) return AppColors.successBg;
    if (lower.contains('cancel')) return AppColors.warningBg;
    return AppColors.infoBg;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Item Movements',
            subtitle: 'Track all stock changes and price updates',
            actions: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int?>(
                  initialValue: _filterItemId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by item',
                    prefixIcon: Icon(Icons.filter_list, size: 18),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Items', style: TextStyle(fontSize: 13)),
                    ),
                    ..._items.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.name, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterItemId = value;
                    });
                    _load();
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_movements.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timeline_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No movements found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Stock movements will appear here as transactions occur.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Movements table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Table header
                    Container(
                      color: AppColors.tableHeaderBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _tableHeader('Item', flex: 3),
                          _tableHeader('Action', flex: 2),
                          _tableHeader('Qty Change', flex: 2, align: TextAlign.right),
                          _tableHeader('Stock', flex: 2, align: TextAlign.center),
                          _tableHeader('Price', flex: 2, align: TextAlign.center),
                          _tableHeader('Reference', flex: 2),
                          _tableHeader('Time', flex: 2),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.border),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _movements.length,
                        separatorBuilder: (_, _) =>
                            Container(height: 1, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final m = _movements[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    m.itemName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _actionBgColor(m.actionType),
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Text(
                                        m.actionType,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _actionColor(m.actionType),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${m.quantityDelta >= 0 ? '+' : ''}${m.quantityDelta}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: m.quantityDelta >= 0
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${m.previousStock} → ${m.newStock}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${formatNullableCurrency(m.previousPrice)} → ${formatNullableCurrency(m.newPrice)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${m.referenceType}/${m.referenceId}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    formatDateTime(m.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
