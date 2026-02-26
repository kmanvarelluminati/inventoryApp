import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Item Movements',
            actions: [
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
