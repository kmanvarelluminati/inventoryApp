import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/utils/formatters.dart';
import 'package:stock_manager/widgets/desktop_page_header.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Sales',
            actions: [
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
