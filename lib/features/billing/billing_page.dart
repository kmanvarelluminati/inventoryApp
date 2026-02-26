import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
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
  int _lineCounter = 0;

  @override
  void initState() {
    super.initState();
    _addLine();
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

  void _addLine() {
    setState(() {
      _lineCounter += 1;
      _lines.add(BillLineEditor(id: _lineCounter));
    });
  }

  void _removeLine(BillLineEditor line) {
    if (_lines.length <= 1) {
      return;
    }

    setState(() {
      _lines.remove(line);
      line.dispose();
    });
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
      _addLine();
      await _loadItems();
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Billing',
            actions: [
              Chip(
                label: Text(
                  widget.manualPriceOverrideEnabled
                      ? 'Manual Price Override: Enabled'
                      : 'Manual Price Override: Disabled',
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _loadItems,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Stock'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                final selectedItem = _itemById(line.itemId);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Line ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (_lines.length > 1)
                              IconButton(
                                onPressed: () => _removeLine(line),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove line',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 320,
                              child: DropdownButtonFormField<int>(
                                initialValue: line.itemId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Item',
                                  border: OutlineInputBorder(),
                                ),
                                items: _items
                                    .map(
                                      (item) => DropdownMenuItem<int>(
                                        value: item.id,
                                        child: Text(
                                          '${item.name} (Stock: ${item.currentStock})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    line.itemId = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: TextField(
                                controller: line.qtyController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: TextField(
                                controller: line.priceController,
                                enabled: widget.manualPriceOverrideEnabled,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: widget.manualPriceOverrideEnabled
                                      ? 'Manual Unit Price'
                                      : 'Manual Unit Price (disabled)',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            if (selectedItem != null)
                              Text(
                                'Default Price: ${formatCurrency(selectedItem.currentPrice)}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Line'),
                ),
                const SizedBox(width: 16),
                Text(
                  'Draft Total: ${formatCurrency(_calculateDraftTotal())}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submitBill,
                  icon: const Icon(Icons.check_circle_outline),
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
  BillLineEditor({required this.id});

  final int id;
  int? itemId;
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}
