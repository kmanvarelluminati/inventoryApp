import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows && !Platform.isMacOS) {
    runApp(const UnsupportedPlatformApp());
    return;
  }

  final db = await AppDatabase.open();
  runApp(InventoryBillingApp(database: db));
}

class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'This application supports only macOS and Windows desktop.',
          ),
        ),
      ),
    );
  }
}

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
      home: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 980) {
            return Scaffold(
              appBar: AppBar(title: const Text('Inventory and Billing System')),
              body: _buildPage(),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    _selectedIndex = value;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    label: 'Items',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    label: 'Billing',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history),
                    label: 'Sales',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.timeline_outlined),
                    label: 'Movements',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.summarize_outlined),
                    label: 'Reports',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: 'Settings',
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      _selectedIndex = value;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
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
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: const Text(
                          'Inventory and Billing System',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: _buildPage()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ItemMasterPage extends StatefulWidget {
  const ItemMasterPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ItemMasterPage> createState() => _ItemMasterPageState();
}

class _ItemMasterPageState extends State<ItemMasterPage> {
  bool _loading = true;
  String? _error;
  List<ItemRecord> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await widget.database.getItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAddItemDialog() async {
    final nameController = TextEditingController();
    final openingQtyController = TextEditingController(text: '0');
    final priceController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Item'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openingQtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Opening Quantity',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Current Price'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) {
      return;
    }

    final itemName = nameController.text.trim();
    final openingQty = int.tryParse(openingQtyController.text.trim());
    final currentPrice = double.tryParse(priceController.text.trim());

    if (itemName.isEmpty || openingQty == null || currentPrice == null) {
      _showMessage('Enter valid item name, quantity, and price.');
      return;
    }

    try {
      await widget.database.createItem(
        name: itemName,
        openingQuantity: openingQty,
        currentPrice: currentPrice,
      );
      _showMessage('Item created.');
      await _load();
    } catch (e) {
      _showMessage('Failed to create item: $e');
    }
  }

  Future<void> _showAddStockDialog(ItemRecord item) async {
    final quantityController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Stock: ${item.name}'),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity to Add'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      _showMessage('Enter a valid positive quantity.');
      return;
    }

    try {
      await widget.database.addStock(itemId: item.id, quantity: quantity);
      _showMessage('Stock updated.');
      await _load();
    } catch (e) {
      _showMessage('Failed to add stock: $e');
    }
  }

  Future<void> _showUpdatePriceDialog(ItemRecord item) async {
    final priceController = TextEditingController(
      text: item.currentPrice.toStringAsFixed(2),
    );

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Price: ${item.name}'),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'New Price'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      return;
    }

    final price = double.tryParse(priceController.text.trim());
    if (price == null || price < 0) {
      _showMessage('Enter a valid price.');
      return;
    }

    try {
      await widget.database.updateItemPrice(itemId: item.id, newPrice: price);
      _showMessage('Price updated for future sales.');
      await _load();
    } catch (e) {
      _showMessage('Failed to update price: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Item Master',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _showAddItemDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else if (_items.isEmpty)
            const Expanded(child: Center(child: Text('No items found.')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 4,
                                  children: [
                                    Text('Stock: ${item.currentStock}'),
                                    Text(
                                      'Price: ${formatCurrency(item.currentPrice)}',
                                    ),
                                    Text(
                                      'Updated: ${formatDateTime(item.updatedAt)}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _showAddStockDialog(item),
                                child: const Text('Add Stock'),
                              ),
                              OutlinedButton(
                                onPressed: () => _showUpdatePriceDialog(item),
                                child: const Text('Update Price'),
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
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Multi-Item Billing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Chip(
                label: Text(
                  widget.manualPriceOverrideEnabled
                      ? 'Manual Price Override: Enabled'
                      : 'Manual Price Override: Disabled',
                ),
              ),
              const Spacer(),
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
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Add Line'),
              ),
              const Spacer(),
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
        ],
      ),
    );
  }
}

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  bool _loading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  List<BillSummary> _bills = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? get _endExclusive {
    if (_endDate == null) {
      return null;
    }
    return _endDate!.add(const Duration(days: 1));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final bills = await widget.database.getBills(
      startDateInclusive: _startDate,
      endDateExclusive: _endExclusive,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _bills = bills;
      _loading = false;
    });
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = DateTime(selected.year, selected.month, selected.day);
    });
    await _load();
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = DateTime(selected.year, selected.month, selected.day);
    });
    await _load();
  }

  Future<void> _viewBillDetails(BillSummary summary) async {
    try {
      final details = await widget.database.getBillDetails(summary.id);
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Bill ${details.billNo}'),
            content: SizedBox(
              width: 640,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${details.status}'),
                  Text('Created: ${formatDateTime(details.createdAt)}'),
                  if (details.cancelledAt != null)
                    Text('Cancelled: ${formatDateTime(details.cancelledAt!)}'),
                  const SizedBox(height: 10),
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: details.lines.length,
                      itemBuilder: (context, index) {
                        final line = details.lines[index];
                        return ListTile(
                          dense: true,
                          title: Text(line.itemName),
                          subtitle: Text('Qty: ${line.quantity}'),
                          trailing: Text(
                            '${formatCurrency(line.unitPriceAtSale)} x ${line.quantity} = ${formatCurrency(line.lineTotal)}',
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Total: ${formatCurrency(details.grossTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showMessage('Failed to load bill details: $e');
    }
  }

  Future<void> _cancelBill(BillSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Bill'),
          content: Text(
            'Cancel bill ${summary.billNo}? Stock will be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Cancel Bill'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.database.cancelBill(summary.id);
      _showMessage('Bill cancelled and stock restored.');
      await _load();
    } catch (e) {
      _showMessage('Failed to cancel bill: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Sales History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickStartDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _startDate == null
                      ? 'Start Date'
                      : 'Start: ${formatDate(_startDate!)}',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickEndDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _endDate == null
                      ? 'End Date'
                      : 'End: ${formatDate(_endDate!)}',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _load();
                },
                child: const Text('Clear Filter'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_bills.isEmpty)
            const Expanded(child: Center(child: Text('No bills found.')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _bills.length,
                itemBuilder: (context, index) {
                  final bill = _bills[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${bill.billNo} - ${formatCurrency(bill.grossTotal)}',
                      ),
                      subtitle: Text(
                        '${formatDateTime(bill.createdAt)} | Status: ${bill.status}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _viewBillDetails(bill),
                            child: const Text('Details'),
                          ),
                          if (bill.status == BillStatus.active)
                            FilledButton.tonal(
                              onPressed: () => _cancelBill(bill),
                              child: const Text('Cancel Bill'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Item Movement History (Audit Trail)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<int?>(
                  initialValue: _filterItemId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Item',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Items'),
                    ),
                    ..._items.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.name),
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_movements.isEmpty)
            const Expanded(child: Center(child: Text('No movements found.')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _movements.length,
                itemBuilder: (context, index) {
                  final movement = _movements[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                movement.itemName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Chip(label: Text(movement.actionType)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Time: ${formatDateTime(movement.createdAt)}',
                              ),
                              Text('Qty Δ: ${movement.quantityDelta}'),
                              Text(
                                'Stock: ${movement.previousStock} -> ${movement.newStock}',
                              ),
                              Text('Balance: ${movement.runningBalance}'),
                              Text(
                                'Price: ${formatNullableCurrency(movement.previousPrice)} -> ${formatNullableCurrency(movement.newPrice)}',
                              ),
                              Text(
                                'Ref: ${movement.referenceType}/${movement.referenceId}',
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
        ],
      ),
    );
  }
}

class DailySummaryPage extends StatefulWidget {
  const DailySummaryPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<DailySummaryPage> createState() => _DailySummaryPageState();
}

class _DailySummaryPageState extends State<DailySummaryPage> {
  bool _loading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  SummaryTotals _totals = const SummaryTotals(
    totalBills: 0,
    totalItemsSold: 0,
    totalSalesAmount: 0,
  );
  List<DailySummaryRecord> _dailyRows = const [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = _startDate;
    _load();
  }

  DateTime? get _endExclusive {
    if (_endDate == null) {
      return null;
    }
    return _endDate!.add(const Duration(days: 1));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final totals = await widget.database.getSummaryTotals(
      startDateInclusive: _startDate,
      endDateExclusive: _endExclusive,
    );

    final dailyRows = await widget.database.getDailySummaries(
      startDateInclusive: _startDate,
      endDateExclusive: _endExclusive,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _totals = totals;
      _dailyRows = dailyRows;
      _loading = false;
    });
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = DateTime(selected.year, selected.month, selected.day);
    });
    await _load();
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = DateTime(selected.year, selected.month, selected.day);
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Daily Summary and Reporting',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickStartDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _startDate == null
                      ? 'Start Date'
                      : 'Start: ${formatDate(_startDate!)}',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickEndDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _endDate == null
                      ? 'End Date'
                      : 'End: ${formatDate(_endDate!)}',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _load();
                },
                child: const Text('Clear Filter'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryCard(
                        label: 'Total Bills',
                        value: _totals.totalBills.toString(),
                      ),
                      _SummaryCard(
                        label: 'Total Items Sold',
                        value: _totals.totalItemsSold.toString(),
                      ),
                      _SummaryCard(
                        label: 'Total Sales Amount',
                        value: formatCurrency(_totals.totalSalesAmount),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Date-wise Breakdown',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _dailyRows.isEmpty
                        ? const Center(
                            child: Text('No summary data for selected period.'),
                          )
                        : ListView.builder(
                            itemCount: _dailyRows.length,
                            itemBuilder: (context, index) {
                              final row = _dailyRows[index];
                              return Card(
                                child: ListTile(
                                  title: Text(row.day),
                                  subtitle: Text(
                                    'Bills: ${row.totalBills} | Items: ${row.totalItemsSold}',
                                  ),
                                  trailing: Text(
                                    formatCurrency(row.totalSalesAmount),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
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

class BillLineInput {
  const BillLineInput({
    required this.itemId,
    required this.quantity,
    this.manualUnitPrice,
  });

  final int itemId;
  final int quantity;
  final double? manualUnitPrice;
}

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;
    final dbDirectory = await dbFactory.getDatabasesPath();
    final dbPath = '$dbDirectory${Platform.pathSeparator}inventory_billing.db';

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON;');
          await database.execute('PRAGMA journal_mode = WAL;');
        },
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              current_stock INTEGER NOT NULL CHECK (current_stock >= 0),
              current_price REAL NOT NULL CHECK (current_price >= 0),
              barcode TEXT,
              low_stock_threshold INTEGER,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');

          await database.execute('''
            CREATE TABLE stock_ledger (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              item_id INTEGER NOT NULL,
              action_type TEXT NOT NULL,
              qty_delta INTEGER NOT NULL,
              prev_stock INTEGER NOT NULL CHECK (prev_stock >= 0),
              new_stock INTEGER NOT NULL CHECK (new_stock >= 0),
              prev_price REAL,
              new_price REAL,
              ref_type TEXT NOT NULL,
              ref_id TEXT NOT NULL,
              running_balance INTEGER NOT NULL CHECK (running_balance >= 0),
              created_at TEXT NOT NULL,
              FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE RESTRICT
            );
          ''');

          await database.execute(
            'CREATE INDEX idx_stock_ledger_item_time ON stock_ledger(item_id, created_at DESC);',
          );

          await database.execute('''
            CREATE TABLE bills (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              bill_no TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL CHECK (status IN ('active', 'cancelled')),
              gross_total REAL NOT NULL CHECK (gross_total >= 0),
              created_at TEXT NOT NULL,
              cancelled_at TEXT
            );
          ''');

          await database.execute('''
            CREATE TABLE bill_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              bill_id INTEGER NOT NULL,
              item_id INTEGER NOT NULL,
              qty INTEGER NOT NULL CHECK (qty > 0),
              unit_price_at_sale REAL NOT NULL CHECK (unit_price_at_sale >= 0),
              line_total REAL NOT NULL CHECK (line_total >= 0),
              FOREIGN KEY(bill_id) REFERENCES bills(id) ON DELETE RESTRICT,
              FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE RESTRICT
            );
          ''');

          await database.execute(
            'CREATE INDEX idx_bill_items_bill ON bill_items(bill_id);',
          );

          await database.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
          ''');

          await database.insert('app_settings', {
            'key': 'manual_price_override',
            'value': '0',
          });
        },
      ),
    );

    await db.insert('app_settings', {
      'key': 'manual_price_override',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return AppDatabase._(db);
  }

  Future<List<ItemRecord>> getItems() async {
    final rows = await _db.query('items', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(ItemRecord.fromMap).toList();
  }

  Future<bool> getManualPriceOverrideEnabled() async {
    final rows = await _db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['manual_price_override'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    return _string(rows.first['value']) == '1';
  }

  Future<void> setManualPriceOverrideEnabled(bool enabled) async {
    await _db.insert('app_settings', {
      'key': 'manual_price_override',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> createItem({
    required String name,
    required int openingQuantity,
    required double currentPrice,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Item name cannot be empty.');
    }
    if (openingQuantity < 0) {
      throw ArgumentError('Opening quantity cannot be negative.');
    }
    if (currentPrice < 0) {
      throw ArgumentError('Current price cannot be negative.');
    }

    final now = _nowIso();

    await _db.transaction((txn) async {
      final itemId = await txn.insert('items', {
        'name': name.trim(),
        'current_stock': openingQuantity,
        'current_price': currentPrice,
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('stock_ledger', {
        'item_id': itemId,
        'action_type': StockAction.openingStock,
        'qty_delta': openingQuantity,
        'prev_stock': 0,
        'new_stock': openingQuantity,
        'prev_price': null,
        'new_price': currentPrice,
        'ref_type': 'item',
        'ref_id': 'ITEM-$itemId',
        'running_balance': openingQuantity,
        'created_at': now,
      });
    });
  }

  Future<void> addStock({required int itemId, required int quantity}) async {
    if (quantity <= 0) {
      throw ArgumentError('Stock add quantity must be greater than zero.');
    }

    final now = _nowIso();

    await _db.transaction((txn) async {
      final item = await _getItemById(txn, itemId);
      if (item == null) {
        throw StateError('Item not found.');
      }

      final previousStock = item.currentStock;
      final newStock = previousStock + quantity;

      final updateCount = await txn.update(
        'items',
        {'current_stock': newStock, 'updated_at': now},
        where: 'id = ? AND current_stock = ?',
        whereArgs: [itemId, previousStock],
      );
      if (updateCount != 1) {
        throw StateError('Concurrent stock update detected.');
      }

      await txn.insert('stock_ledger', {
        'item_id': itemId,
        'action_type': StockAction.stockAdded,
        'qty_delta': quantity,
        'prev_stock': previousStock,
        'new_stock': newStock,
        'prev_price': item.currentPrice,
        'new_price': item.currentPrice,
        'ref_type': 'stock',
        'ref_id': 'STK-${DateTime.now().millisecondsSinceEpoch}',
        'running_balance': newStock,
        'created_at': now,
      });
    });
  }

  Future<void> updateItemPrice({
    required int itemId,
    required double newPrice,
  }) async {
    if (newPrice < 0) {
      throw ArgumentError('Price cannot be negative.');
    }

    final now = _nowIso();

    await _db.transaction((txn) async {
      final item = await _getItemById(txn, itemId);
      if (item == null) {
        throw StateError('Item not found.');
      }

      final oldPrice = item.currentPrice;
      if (oldPrice == newPrice) {
        return;
      }

      final updateCount = await txn.update(
        'items',
        {'current_price': newPrice, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (updateCount != 1) {
        throw StateError('Failed to update item price.');
      }

      await txn.insert('stock_ledger', {
        'item_id': itemId,
        'action_type': StockAction.priceUpdated,
        'qty_delta': 0,
        'prev_stock': item.currentStock,
        'new_stock': item.currentStock,
        'prev_price': oldPrice,
        'new_price': newPrice,
        'ref_type': 'price',
        'ref_id': 'PRC-${DateTime.now().millisecondsSinceEpoch}',
        'running_balance': item.currentStock,
        'created_at': now,
      });
    });
  }

  Future<String> createBill(
    List<BillLineInput> lines, {
    required bool manualPriceOverrideEnabled,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Bill must contain at least one line item.');
    }

    final seen = <int>{};
    for (final line in lines) {
      if (line.quantity <= 0) {
        throw ArgumentError('Bill item quantity must be positive.');
      }
      if (!seen.add(line.itemId)) {
        throw ArgumentError('Duplicate items in bill are not allowed.');
      }
    }

    final now = _nowIso();

    return _db.transaction<String>((txn) async {
      final itemsById = <int, ItemRecord>{};
      for (final line in lines) {
        final item = await _getItemById(txn, line.itemId);
        if (item == null) {
          throw StateError('Item not found: ${line.itemId}');
        }

        if (item.currentStock < line.quantity) {
          throw StateError(
            'Insufficient stock for ${item.name}. Available: ${item.currentStock}, requested: ${line.quantity}.',
          );
        }

        itemsById[line.itemId] = item;
      }

      final billNo = await _generateBillNo(txn);
      final billId = await txn.insert('bills', {
        'bill_no': billNo,
        'status': BillStatus.active.name,
        'gross_total': 0,
        'created_at': now,
        'cancelled_at': null,
      });

      var grossTotal = 0.0;
      final currentStocks = <int, int>{
        for (final entry in itemsById.entries)
          entry.key: entry.value.currentStock,
      };

      for (final line in lines) {
        final item = itemsById[line.itemId]!;
        final previousStock = currentStocks[line.itemId]!;
        final newStock = previousStock - line.quantity;
        if (newStock < 0) {
          throw StateError('Stock cannot go below zero.');
        }

        final chosenPrice =
            manualPriceOverrideEnabled && line.manualUnitPrice != null
            ? line.manualUnitPrice!
            : item.currentPrice;

        if (chosenPrice < 0) {
          throw StateError('Sale price cannot be negative.');
        }

        final lineTotal = chosenPrice * line.quantity;
        grossTotal += lineTotal;

        final updateCount = await txn.update(
          'items',
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ? AND current_stock = ?',
          whereArgs: [line.itemId, previousStock],
        );

        if (updateCount != 1) {
          throw StateError(
            'Concurrent stock update detected for item: ${item.name}',
          );
        }

        currentStocks[line.itemId] = newStock;

        await txn.insert('bill_items', {
          'bill_id': billId,
          'item_id': line.itemId,
          'qty': line.quantity,
          'unit_price_at_sale': chosenPrice,
          'line_total': lineTotal,
        });

        await txn.insert('stock_ledger', {
          'item_id': line.itemId,
          'action_type': StockAction.sold,
          'qty_delta': -line.quantity,
          'prev_stock': previousStock,
          'new_stock': newStock,
          'prev_price': item.currentPrice,
          'new_price': item.currentPrice,
          'ref_type': 'bill',
          'ref_id': billNo,
          'running_balance': newStock,
          'created_at': now,
        });
      }

      await txn.update(
        'bills',
        {'gross_total': grossTotal},
        where: 'id = ?',
        whereArgs: [billId],
      );

      return billNo;
    });
  }

  Future<List<BillSummary>> getBills({
    DateTime? startDateInclusive,
    DateTime? endDateExclusive,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];

    if (startDateInclusive != null) {
      clauses.add('created_at >= ?');
      args.add(startDateInclusive.toIso8601String());
    }

    if (endDateExclusive != null) {
      clauses.add('created_at < ?');
      args.add(endDateExclusive.toIso8601String());
    }

    final rows = await _db.query(
      'bills',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );

    return rows.map(BillSummary.fromMap).toList();
  }

  Future<BillDetails> getBillDetails(int billId) async {
    final billRows = await _db.query(
      'bills',
      where: 'id = ?',
      whereArgs: [billId],
      limit: 1,
    );

    if (billRows.isEmpty) {
      throw StateError('Bill not found.');
    }

    final bill = billRows.first;

    final lineRows = await _db.rawQuery(
      '''
      SELECT
        bi.id,
        bi.bill_id,
        bi.item_id,
        i.name AS item_name,
        bi.qty,
        bi.unit_price_at_sale,
        bi.line_total
      FROM bill_items bi
      JOIN items i ON i.id = bi.item_id
      WHERE bi.bill_id = ?
      ORDER BY bi.id ASC
      ''',
      [billId],
    );

    return BillDetails(
      id: _intValue(bill['id']),
      billNo: _string(bill['bill_no']),
      status: BillStatus.values.byName(_string(bill['status'])),
      grossTotal: _doubleValue(bill['gross_total']),
      createdAt: _string(bill['created_at']),
      cancelledAt: _nullableString(bill['cancelled_at']),
      lines: lineRows.map(BillLineDetail.fromMap).toList(),
    );
  }

  Future<void> cancelBill(int billId) async {
    final now = _nowIso();

    await _db.transaction((txn) async {
      final billRows = await txn.query(
        'bills',
        where: 'id = ?',
        whereArgs: [billId],
        limit: 1,
      );

      if (billRows.isEmpty) {
        throw StateError('Bill not found.');
      }

      final bill = billRows.first;
      final status = BillStatus.values.byName(_string(bill['status']));
      if (status == BillStatus.cancelled) {
        throw StateError('Bill is already cancelled.');
      }

      final billNo = _string(bill['bill_no']);

      final lineRows = await txn.rawQuery(
        '''
        SELECT
          bi.item_id,
          bi.qty,
          i.name AS item_name,
          i.current_stock,
          i.current_price
        FROM bill_items bi
        JOIN items i ON i.id = bi.item_id
        WHERE bi.bill_id = ?
        ORDER BY bi.id ASC
        ''',
        [billId],
      );

      for (final row in lineRows) {
        final itemId = _intValue(row['item_id']);
        final quantity = _intValue(row['qty']);
        final previousStock = _intValue(row['current_stock']);
        final newStock = previousStock + quantity;
        final currentPrice = _doubleValue(row['current_price']);

        final updateCount = await txn.update(
          'items',
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ? AND current_stock = ?',
          whereArgs: [itemId, previousStock],
        );

        if (updateCount != 1) {
          throw StateError('Concurrent stock update detected during cancel.');
        }

        await txn.insert('stock_ledger', {
          'item_id': itemId,
          'action_type': StockAction.stockAdjustment,
          'qty_delta': quantity,
          'prev_stock': previousStock,
          'new_stock': newStock,
          'prev_price': currentPrice,
          'new_price': currentPrice,
          'ref_type': 'bill_cancel',
          'ref_id': billNo,
          'running_balance': newStock,
          'created_at': now,
        });
      }

      await txn.update(
        'bills',
        {'status': BillStatus.cancelled.name, 'cancelled_at': now},
        where: 'id = ?',
        whereArgs: [billId],
      );
    });
  }

  Future<List<StockMovementRecord>> getStockMovements({int? itemId}) async {
    final rows = await _db.rawQuery('''
      SELECT
        sl.id,
        sl.item_id,
        i.name AS item_name,
        sl.action_type,
        sl.qty_delta,
        sl.prev_stock,
        sl.new_stock,
        sl.prev_price,
        sl.new_price,
        sl.ref_type,
        sl.ref_id,
        sl.running_balance,
        sl.created_at
      FROM stock_ledger sl
      JOIN items i ON i.id = sl.item_id
      ${itemId == null ? '' : 'WHERE sl.item_id = ?'}
      ORDER BY sl.created_at DESC, sl.id DESC
      ''', itemId == null ? null : [itemId]);

    return rows.map(StockMovementRecord.fromMap).toList();
  }

  Future<SummaryTotals> getSummaryTotals({
    DateTime? startDateInclusive,
    DateTime? endDateExclusive,
  }) async {
    final clauses = <String>['b.status = ?'];
    final args = <Object?>[BillStatus.active.name];

    if (startDateInclusive != null) {
      clauses.add('b.created_at >= ?');
      args.add(startDateInclusive.toIso8601String());
    }

    if (endDateExclusive != null) {
      clauses.add('b.created_at < ?');
      args.add(endDateExclusive.toIso8601String());
    }

    final rows = await _db.rawQuery('''
      SELECT
        COUNT(DISTINCT b.id) AS total_bills,
        COALESCE(SUM(bi.qty), 0) AS total_items_sold,
        COALESCE(SUM(bi.line_total), 0) AS total_sales_amount
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE ${clauses.join(' AND ')}
      ''', args);

    final row = rows.first;
    return SummaryTotals(
      totalBills: _intValue(row['total_bills']),
      totalItemsSold: _intValue(row['total_items_sold']),
      totalSalesAmount: _doubleValue(row['total_sales_amount']),
    );
  }

  Future<List<DailySummaryRecord>> getDailySummaries({
    DateTime? startDateInclusive,
    DateTime? endDateExclusive,
  }) async {
    final clauses = <String>['b.status = ?'];
    final args = <Object?>[BillStatus.active.name];

    if (startDateInclusive != null) {
      clauses.add('b.created_at >= ?');
      args.add(startDateInclusive.toIso8601String());
    }

    if (endDateExclusive != null) {
      clauses.add('b.created_at < ?');
      args.add(endDateExclusive.toIso8601String());
    }

    final rows = await _db.rawQuery('''
      SELECT
        SUBSTR(b.created_at, 1, 10) AS day,
        COUNT(DISTINCT b.id) AS total_bills,
        COALESCE(SUM(bi.qty), 0) AS total_items_sold,
        COALESCE(SUM(bi.line_total), 0) AS total_sales_amount
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE ${clauses.join(' AND ')}
      GROUP BY SUBSTR(b.created_at, 1, 10)
      ORDER BY day DESC
      ''', args);

    return rows.map(DailySummaryRecord.fromMap).toList();
  }

  Future<ItemRecord?> _getItemById(DatabaseExecutor db, int itemId) async {
    final rows = await db.query('items', where: 'id = ?', whereArgs: [itemId]);
    if (rows.isEmpty) {
      return null;
    }
    return ItemRecord.fromMap(rows.first);
  }

  Future<String> _generateBillNo(DatabaseExecutor db) async {
    final random = Random();

    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate =
          'B${DateTime.now().millisecondsSinceEpoch}${100 + random.nextInt(900)}';

      final exists = await db.query(
        'bills',
        columns: ['id'],
        where: 'bill_no = ?',
        whereArgs: [candidate],
        limit: 1,
      );

      if (exists.isEmpty) {
        return candidate;
      }
    }

    throw StateError('Failed to generate unique bill number.');
  }
}

enum BillStatus { active, cancelled }

class StockAction {
  static const String openingStock = 'Opening Stock';
  static const String stockAdded = 'Stock Added';
  static const String sold = 'Sold';
  static const String priceUpdated = 'Price Updated';
  static const String stockAdjustment = 'Stock Adjustment';
}

class ItemRecord {
  const ItemRecord({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.currentPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int currentStock;
  final double currentPrice;
  final String createdAt;
  final String updatedAt;

  factory ItemRecord.fromMap(Map<String, Object?> map) {
    return ItemRecord(
      id: _intValue(map['id']),
      name: _string(map['name']),
      currentStock: _intValue(map['current_stock']),
      currentPrice: _doubleValue(map['current_price']),
      createdAt: _string(map['created_at']),
      updatedAt: _string(map['updated_at']),
    );
  }
}

class BillSummary {
  const BillSummary({
    required this.id,
    required this.billNo,
    required this.status,
    required this.grossTotal,
    required this.createdAt,
    this.cancelledAt,
  });

  final int id;
  final String billNo;
  final BillStatus status;
  final double grossTotal;
  final String createdAt;
  final String? cancelledAt;

  factory BillSummary.fromMap(Map<String, Object?> map) {
    return BillSummary(
      id: _intValue(map['id']),
      billNo: _string(map['bill_no']),
      status: BillStatus.values.byName(_string(map['status'])),
      grossTotal: _doubleValue(map['gross_total']),
      createdAt: _string(map['created_at']),
      cancelledAt: _nullableString(map['cancelled_at']),
    );
  }
}

class BillLineDetail {
  const BillLineDetail({
    required this.id,
    required this.billId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPriceAtSale,
    required this.lineTotal,
  });

  final int id;
  final int billId;
  final int itemId;
  final String itemName;
  final int quantity;
  final double unitPriceAtSale;
  final double lineTotal;

  factory BillLineDetail.fromMap(Map<String, Object?> map) {
    return BillLineDetail(
      id: _intValue(map['id']),
      billId: _intValue(map['bill_id']),
      itemId: _intValue(map['item_id']),
      itemName: _string(map['item_name']),
      quantity: _intValue(map['qty']),
      unitPriceAtSale: _doubleValue(map['unit_price_at_sale']),
      lineTotal: _doubleValue(map['line_total']),
    );
  }
}

class BillDetails {
  const BillDetails({
    required this.id,
    required this.billNo,
    required this.status,
    required this.grossTotal,
    required this.createdAt,
    required this.lines,
    this.cancelledAt,
  });

  final int id;
  final String billNo;
  final BillStatus status;
  final double grossTotal;
  final String createdAt;
  final String? cancelledAt;
  final List<BillLineDetail> lines;
}

class StockMovementRecord {
  const StockMovementRecord({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.actionType,
    required this.quantityDelta,
    required this.previousStock,
    required this.newStock,
    required this.previousPrice,
    required this.newPrice,
    required this.referenceType,
    required this.referenceId,
    required this.runningBalance,
    required this.createdAt,
  });

  final int id;
  final int itemId;
  final String itemName;
  final String actionType;
  final int quantityDelta;
  final int previousStock;
  final int newStock;
  final double? previousPrice;
  final double? newPrice;
  final String referenceType;
  final String referenceId;
  final int runningBalance;
  final String createdAt;

  factory StockMovementRecord.fromMap(Map<String, Object?> map) {
    return StockMovementRecord(
      id: _intValue(map['id']),
      itemId: _intValue(map['item_id']),
      itemName: _string(map['item_name']),
      actionType: _string(map['action_type']),
      quantityDelta: _intValue(map['qty_delta']),
      previousStock: _intValue(map['prev_stock']),
      newStock: _intValue(map['new_stock']),
      previousPrice: map['prev_price'] == null
          ? null
          : _doubleValue(map['prev_price']),
      newPrice: map['new_price'] == null
          ? null
          : _doubleValue(map['new_price']),
      referenceType: _string(map['ref_type']),
      referenceId: _string(map['ref_id']),
      runningBalance: _intValue(map['running_balance']),
      createdAt: _string(map['created_at']),
    );
  }
}

class SummaryTotals {
  const SummaryTotals({
    required this.totalBills,
    required this.totalItemsSold,
    required this.totalSalesAmount,
  });

  final int totalBills;
  final int totalItemsSold;
  final double totalSalesAmount;
}

class DailySummaryRecord {
  const DailySummaryRecord({
    required this.day,
    required this.totalBills,
    required this.totalItemsSold,
    required this.totalSalesAmount,
  });

  final String day;
  final int totalBills;
  final int totalItemsSold;
  final double totalSalesAmount;

  factory DailySummaryRecord.fromMap(Map<String, Object?> map) {
    return DailySummaryRecord(
      day: _string(map['day']),
      totalBills: _intValue(map['total_bills']),
      totalItemsSold: _intValue(map['total_items_sold']),
      totalSalesAmount: _doubleValue(map['total_sales_amount']),
    );
  }
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.parse(value.toString());
}

double _doubleValue(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
}

String _string(Object? value) {
  return value?.toString() ?? '';
}

String? _nullableString(Object? value) {
  return value?.toString();
}

String _nowIso() => DateTime.now().toIso8601String();

String formatCurrency(double value) {
  return '\$${value.toStringAsFixed(2)}';
}

String formatNullableCurrency(double? value) {
  if (value == null) {
    return '-';
  }
  return formatCurrency(value);
}

String formatDate(DateTime date) {
  return '${date.year}-${_pad2(date.month)}-${_pad2(date.day)}';
}

String formatDateTime(String isoTimestamp) {
  DateTime parsed;
  try {
    parsed = DateTime.parse(isoTimestamp);
  } catch (_) {
    return isoTimestamp;
  }
  return '${parsed.year}-${_pad2(parsed.month)}-${_pad2(parsed.day)} '
      '${_pad2(parsed.hour)}:${_pad2(parsed.minute)}';
}

String _pad2(int value) => value.toString().padLeft(2, '0');
