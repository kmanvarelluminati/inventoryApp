import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/theme/app_theme.dart';
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
            title: Row(
              children: [
                Text('Bill ${details.billNo}'),
                const SizedBox(width: 10),
                _statusBadge(details.status),
              ],
            ),
            content: SizedBox(
              width: 640,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.tableHeaderBg,
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: Row(
                      children: [
                        _metaItem('Created', formatDateTime(details.createdAt)),
                        if (details.cancelledAt != null)
                          _metaItem('Cancelled', formatDateTime(details.cancelledAt!)),
                        const Spacer(),
                        Text(
                          formatCurrency(details.grossTotal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LINE ITEMS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Items table
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: details.lines.length,
                        separatorBuilder: (_, _) =>
                            Container(height: 1, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final line = details.lines[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    line.itemName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${formatCurrency(line.unitPriceAtSale)} x ${line.quantity}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  formatCurrency(line.lineTotal),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
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

  Widget _statusBadge(BillStatus status) {
    final isActive = status == BillStatus.active;
    final label = isActive ? 'ACTIVE' : 'CANCELLED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successBg : AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.danger,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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
            title: 'Sales History',
            subtitle: 'View and manage sales bills',
            actions: [
              OutlinedButton.icon(
                onPressed: _pickStartDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 14),
                label: Text(
                  _startDate == null
                      ? 'Start Date'
                      : 'From: ${formatDate(_startDate!)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickEndDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 14),
                label: Text(
                  _endDate == null
                      ? 'End Date'
                      : 'To: ${formatDate(_endDate!)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (_startDate != null || _endDate != null)
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _load();
                  },
                  child: const Text('Clear'),
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
          else if (_bills.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No bills found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bills will appear here once created.',
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
            // Sales table
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
                          _tableHeader('Bill No.', flex: 2),
                          _tableHeader('Date', flex: 3),
                          _tableHeader('Status', flex: 2),
                          _tableHeader('Amount', flex: 2, align: TextAlign.right),
                          _tableHeader('Actions', flex: 2, align: TextAlign.right),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.border),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _bills.length,
                        separatorBuilder: (_, _) =>
                            Container(height: 1, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final bill = _bills[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    bill.billNo,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatDateTime(bill.createdAt),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _statusBadge(bill.status),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    formatCurrency(bill.grossTotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => _viewBillDetails(bill),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Details'),
                                      ),
                                      if (bill.status == BillStatus.active) ...[
                                        const SizedBox(width: 4),
                                        TextButton(
                                          onPressed: () => _cancelBill(bill),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ],
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
