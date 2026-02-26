import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/utils/formatters.dart';
import 'package:stock_manager/widgets/desktop_page_header.dart';
import 'package:stock_manager/widgets/right_slide_over_panel.dart';

class ItemMasterPage extends StatefulWidget {
  const ItemMasterPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ItemMasterPage> createState() => _ItemMasterPageState();
}

class _ItemMasterPageState extends State<ItemMasterPage> {
  static const List<String> _packingUnits = ['KG', 'Liter', 'ML'];

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
    final hsnCodeController = TextEditingController();
    final packingWeightController = TextEditingController();
    final priceController = TextEditingController();
    var selectedUnit = 'KG';

    bool isFormValid() {
      if (nameController.text.trim().isEmpty) {
        return false;
      }
      if (int.tryParse(hsnCodeController.text.trim()) == null) {
        return false;
      }
      final packingWeight = double.tryParse(
        packingWeightController.text.trim(),
      );
      if (packingWeight == null || packingWeight <= 0) {
        return false;
      }
      final price = double.tryParse(priceController.text.trim());
      if (price == null || price < 0) {
        return false;
      }
      return _packingUnits.contains(selectedUnit);
    }

    final formData = await showRightSlideOverPanel<_AddItemFormData>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setStatePanel) {
          final canCreate = isFormValid();
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Item',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: nameController,
                          onChanged: (_) => setStatePanel(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Item Name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: hsnCodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setStatePanel(() {}),
                          decoration: const InputDecoration(
                            labelText: 'HSN Code',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: packingWeightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                onChanged: (_) => setStatePanel(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Packing Weight',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 130,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                ),
                                items: _packingUnits
                                    .map(
                                      (unit) => DropdownMenuItem<String>(
                                        value: unit,
                                        child: Text(unit),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setStatePanel(() {
                                    selectedUnit = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          onChanged: (_) => setStatePanel(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Unit Price',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: canCreate
                          ? () {
                              Navigator.pop(
                                context,
                                _AddItemFormData(
                                  name: nameController.text.trim(),
                                  hsnCode: hsnCodeController.text.trim(),
                                  packingWeight: double.parse(
                                    packingWeightController.text.trim(),
                                  ),
                                  packingUnit: selectedUnit,
                                  unitPrice: double.parse(
                                    priceController.text.trim(),
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      if (formData == null) {
        return;
      }

      await widget.database.createItem(
        name: formData.name,
        currentPrice: formData.unitPrice,
        hsnCode: formData.hsnCode,
        packingWeight: formData.packingWeight,
        packingUnit: formData.packingUnit,
      );
      _showMessage('Item created.');
      await _load();
    } catch (e) {
      _showMessage('Failed to create item: $e');
    } finally {
      nameController.dispose();
      hsnCodeController.dispose();
      packingWeightController.dispose();
      priceController.dispose();
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Item Master',
            actions: [
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

class _AddItemFormData {
  const _AddItemFormData({
    required this.name,
    required this.hsnCode,
    required this.packingWeight,
    required this.packingUnit,
    required this.unitPrice,
  });

  final String name;
  final String hsnCode;
  final double packingWeight;
  final String packingUnit;
  final double unitPrice;
}
