import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/theme/app_theme.dart';
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Panel header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditMode ? 'Edit Item' : 'Add New Item',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isEditMode
                      ? 'Update the item details below.'
                      : 'Fill in the details to add a new item.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // Form fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFieldLabel('Item Name'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameController,
                          onChanged: (_) => setStatePanel(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Enter item name',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFieldLabel('HSN Code'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: hsnCodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setStatePanel(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Enter HSN code',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFieldLabel(quantityLabel),
                        const SizedBox(height: 6),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setStatePanel(() {}),
                          decoration: InputDecoration(
                            hintText: 'Enter $quantityLabel'.toLowerCase(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFieldLabel('Packing'),
                        const SizedBox(height: 6),
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
                                  hintText: 'Weight',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedUnit,
                                decoration: const InputDecoration(
                                  hintText: 'Unit',
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
                        const SizedBox(height: 16),
                        _buildFieldLabel('Unit Price'),
                        const SizedBox(height: 6),
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
                            hintText: 'Enter price',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer buttons
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
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
                      child: Text(isEditMode ? 'Save Changes' : 'Create Item'),
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

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Item Master',
            subtitle: 'Manage your product catalog',
            actions: [
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: () => _showItemPanel(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            )
          else if (_items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No items found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add your first item to get started.',
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
                          _tableHeader('Name', flex: 3),
                          _tableHeader('HSN Code', flex: 2),
                          _tableHeader('Packing', flex: 2),
                          _tableHeader('Unit Price', flex: 2, align: TextAlign.right),
                          _tableHeader('', flex: 1),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.border),
                    // Table body
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            Container(height: 1, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final item = _items[index];
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
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.hsnCode ?? '-',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatPacking(item),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    formatCurrency(item.currentPrice),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          _showItemPanel(item: item),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Edit'),
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
