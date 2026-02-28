import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/theme/app_theme.dart';
import 'package:stock_manager/utils/formatters.dart';
import 'package:stock_manager/widgets/desktop_page_header.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({
    super.key,
    required this.database,
    required this.manualPriceOverrideEnabled,
  });

  final AppDatabase database;
  final bool manualPriceOverrideEnabled;

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  bool _loading = true;
  bool _submitting = false;
  List<ItemRecord> _items = const [];
  final List<BillLineEditor> _lines = [];
  final TextEditingController _itemSearchController = TextEditingController();
  final FocusNode _itemSearchFocusNode = FocusNode();
  int _lineCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant BillingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manualPriceOverrideEnabled !=
        widget.manualPriceOverrideEnabled) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    _itemSearchFocusNode.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
    });

    final items = await widget.database.getItems();
    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _addLine({int? selectedItemId}) {
    setState(() {
      _lineCounter += 1;
      _lines.add(BillLineEditor(id: _lineCounter, itemId: selectedItemId));
    });
  }

  void _removeLine(BillLineEditor line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  void _addItemToCart(ItemRecord item) {
    final existing = _lines.where((line) => line.itemId == item.id).firstOrNull;
    if (existing != null) {
      final currentQty = int.tryParse(existing.qtyController.text.trim()) ?? 0;
      existing.qtyController.text = (currentQty + 1).toString();
      setState(() {});
    } else {
      _addLine(selectedItemId: item.id);
    }

    _itemSearchController.clear();
    _itemSearchFocusNode.requestFocus();
  }

  ItemRecord? _itemById(int? id) {
    if (id == null) {
      return null;
    }

    for (final item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  double _calculateDraftTotal() {
    var total = 0.0;
    for (final line in _lines) {
      final item = _itemById(line.itemId);
      if (item == null) {
        continue;
      }

      final qty = int.tryParse(line.qtyController.text.trim());
      if (qty == null || qty <= 0) {
        continue;
      }

      final manualPrice = widget.manualPriceOverrideEnabled
          ? double.tryParse(line.priceController.text.trim())
          : null;
      final unitPrice = manualPrice ?? item.currentPrice;
      total += unitPrice * qty;
    }
    return total;
  }

  Future<void> _submitBill() async {
    if (_submitting) {
      return;
    }

    if (_lines.isEmpty) {
      _showMessage('Add at least one item to the bill.');
      return;
    }

    final seenItemIds = <int>{};
    final requestLines = <BillLineInput>[];

    for (final line in _lines) {
      final itemId = line.itemId;
      if (itemId == null) {
        _showMessage('Select an item for every bill line.');
        return;
      }

      if (!seenItemIds.add(itemId)) {
        _showMessage('Duplicate items in one bill are not allowed.');
        return;
      }

      final quantity = int.tryParse(line.qtyController.text.trim());
      if (quantity == null || quantity <= 0) {
        _showMessage('Enter valid positive quantities.');
        return;
      }

      double? manualPrice;
      if (widget.manualPriceOverrideEnabled &&
          line.priceController.text.trim().isNotEmpty) {
        manualPrice = double.tryParse(line.priceController.text.trim());
        if (manualPrice == null || manualPrice < 0) {
          _showMessage('Enter a valid manual price override.');
          return;
        }
      }

      requestLines.add(
        BillLineInput(
          itemId: itemId,
          quantity: quantity,
          manualUnitPrice: manualPrice,
        ),
      );
    }

    setState(() {
      _submitting = true;
    });

    try {
      final billNo = await widget.database.createBill(
        requestLines,
        manualPriceOverrideEnabled: widget.manualPriceOverrideEnabled,
      );
      _showMessage('Bill created successfully: $billNo');

      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
      _lineCounter = 0;
      await _loadItems();
      _itemSearchController.clear();
      _itemSearchFocusNode.requestFocus();
    } catch (e) {
      _showMessage('Failed to create bill: $e');
      await _loadItems();
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Billing',
            subtitle: 'Create and manage sales bills',
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.manualPriceOverrideEnabled
                      ? AppColors.primaryLight
                      : AppColors.tableHeaderBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.manualPriceOverrideEnabled
                          ? Icons.toggle_on
                          : Icons.toggle_off_outlined,
                      size: 16,
                      color: widget.manualPriceOverrideEnabled
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Manual Price ${widget.manualPriceOverrideEnabled ? 'On' : 'Off'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.manualPriceOverrideEnabled
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadItems,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Stock'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: RawAutocomplete<ItemRecord>(
              textEditingController: _itemSearchController,
              focusNode: _itemSearchFocusNode,
              displayStringForOption: (item) => item.name,
              optionsBuilder: (TextEditingValue textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) {
                  return const Iterable<ItemRecord>.empty();
                }
                return _items
                    .where(
                      (item) =>
                          item.name.toLowerCase().contains(query) ||
                          (item.hsnCode ?? '').toLowerCase().contains(query),
                    )
                    .take(20);
              },
              onSelected: _addItemToCart,
              fieldViewBuilder:
                  (
                    context,
                    controller,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => onFieldSubmitted(),
                      decoration: const InputDecoration(
                        hintText: 'Search item by name or HSN and press Enter',
                        prefixIcon: Icon(Icons.search),
                      ),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      width: 640,
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final item = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Stock: ${item.currentStock}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatCurrency(item.currentPrice),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Line items
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              clipBehavior: Clip.antiAlias,
              child: _lines.isEmpty
                  ? const Center(
                      child: Text(
                        'Search and select an item to add it to the bill.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          color: AppColors.tableHeaderBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'ITEM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'QTY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'DEFAULT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(width: 36),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _lines.length,
                            separatorBuilder: (_, _) =>
                                Container(height: 1, color: AppColors.borderLight),
                            itemBuilder: (context, index) {
                              final line = _lines[index];
                              final item = _itemById(line.itemId);
                              if (item == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Stock: ${item.currentStock}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: line.qtyController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          labelText: 'Qty',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        formatCurrency(item.currentPrice),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 36,
                                      child: IconButton(
                                        onPressed: () => _removeLine(line),
                                        icon: const Icon(Icons.close, size: 16),
                                        style: IconButton.styleFrom(
                                          foregroundColor: AppColors.textTertiary,
                                          minimumSize: const Size(28, 28),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        tooltip: 'Remove item',
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

          // Footer
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  'Total: ',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  formatCurrency(_calculateDraftTotal()),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submitBill,
                  icon: Icon(
                    _submitting ? Icons.hourglass_empty : Icons.check_circle_outline,
                    size: 16,
                  ),
                  label: Text(_submitting ? 'Processing...' : 'Confirm Bill'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BillLineEditor {
  BillLineEditor({required this.id, this.itemId});

  final int id;
  int? itemId;
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}
