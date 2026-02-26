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

  Future<void> _showItemPanel({ItemRecord? item}) async {
    final isEditMode = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final hsnCodeController = TextEditingController(text: item?.hsnCode ?? '');
    final packingWeightController = TextEditingController(
      text: item?.packingWeight?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: item != null ? item.currentPrice.toStringAsFixed(2) : '',
    );
    final quantityController = TextEditingController(
      text: item?.currentStock.toString() ?? '0',
    );
    var selectedUnit = _packingUnits.contains(item?.packingUnit)
        ? item!.packingUnit!
        : 'KG';

    bool isFormValid() {
      if (nameController.text.trim().isEmpty) {
        return false;
      }
      if (int.tryParse(hsnCodeController.text.trim()) == null) {
        return false;
      }
      if (int.tryParse(quantityController.text.trim()) == null) {
        return false;
      }
      final quantity = int.parse(quantityController.text.trim());
      if (quantity < 0) {
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

    final formData = await showRightSlideOverPanel<_ItemFormData>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setStatePanel) {
          final canSubmit = isFormValid();
          final quantityLabel = isEditMode
              ? 'Current Quantity'
              : 'Opening Quantity';

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditMode ? 'Edit Item' : 'Add Item',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
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
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setStatePanel(() {}),
                          decoration: InputDecoration(labelText: quantityLabel),
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
                      onPressed: canSubmit
                          ? () {
                              Navigator.pop(
                                context,
                                _ItemFormData(
                                  name: nameController.text.trim(),
                                  hsnCode: hsnCodeController.text.trim(),
                                  quantity: int.parse(
                                    quantityController.text.trim(),
                                  ),
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
                      child: Text(isEditMode ? 'Save' : 'Create'),
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

      if (item == null) {
        await widget.database.createItem(
          name: formData.name,
          openingQuantity: formData.quantity,
          currentPrice: formData.unitPrice,
          hsnCode: formData.hsnCode,
          packingWeight: formData.packingWeight,
          packingUnit: formData.packingUnit,
        );
        _showMessage('Item created.');
      } else {
        await widget.database.updateItemDetails(
          itemId: item.id,
          name: formData.name,
          hsnCode: formData.hsnCode,
          packingWeight: formData.packingWeight,
          packingUnit: formData.packingUnit,
          currentPrice: formData.unitPrice,
          quantity: formData.quantity,
        );
        _showMessage('Item updated.');
      }
      await _load();
    } catch (e) {
      _showMessage('Failed to save item: $e');
    } finally {
      nameController.dispose();
      hsnCodeController.dispose();
      quantityController.dispose();
      packingWeightController.dispose();
      priceController.dispose();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatPacking(ItemRecord item) {
    final weight = item.packingWeight;
    final unit = item.packingUnit;
    if (weight == null || unit == null || unit.isEmpty) {
      return '-';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 2)} $unit';
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Widget _bodyCell(String text, {TextAlign align = TextAlign.left}) {
    return Text(text, textAlign: align);
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
                onPressed: () => _showItemPanel(),
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
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: _headerCell('Name')),
                          Expanded(flex: 2, child: _headerCell('HSN')),
                          Expanded(flex: 2, child: _headerCell('Packing')),
                          Expanded(
                            flex: 2,
                            child: _headerCell(
                              'Unit Price',
                              align: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _headerCell(
                              'Actions',
                              align: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: _bodyCell(item.name)),
                                Expanded(
                                  flex: 2,
                                  child: _bodyCell(item.hsnCode ?? '-'),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: _bodyCell(_formatPacking(item)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: _bodyCell(
                                    formatCurrency(item.currentPrice),
                                    align: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      height: 30,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _showItemPanel(item: item),
                                        child: const Text('Edit'),
                                      ),
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
}

class _ItemFormData {
  const _ItemFormData({
    required this.name,
    required this.hsnCode,
    required this.quantity,
    required this.packingWeight,
    required this.packingUnit,
    required this.unitPrice,
  });

  final String name;
  final String hsnCode;
  final int quantity;
  final double packingWeight;
  final String packingUnit;
  final double unitPrice;
}
