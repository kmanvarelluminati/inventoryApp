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
      final results = await Future.wait([
        widget.database.getBillDetails(summary.id),
        widget.database.getInvoiceProfileSettings(),
      ]);
      final details = results[0] as BillDetails;
      final invoiceProfile = results[1] as InvoiceProfileSettings;
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            title: Row(
              children: [
                const Text('Tax Invoice Preview'),
                const SizedBox(width: 10),
                _statusBadge(details.status),
              ],
            ),
            content: SizedBox(
              width: 1320,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1240,
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.textPrimary, width: 1.4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.textPrimary,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  invoiceProfile.shopName.isEmpty
                                      ? 'SHOP NAME'
                                      : invoiceProfile.shopName.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  invoiceProfile.address.isEmpty
                                      ? 'ADDRESS'
                                      : invoiceProfile.address.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mo:${invoiceProfile.mobile.isEmpty ? '-' : invoiceProfile.mobile}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.textPrimary,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Text(
                              'TAX INVOICE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Table(
                            border: const TableBorder(
                              horizontalInside: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                              verticalInside: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                            ),
                            children: [
                              TableRow(
                                children: [
                                  _invoiceInfoCell(
                                    'Ferti Regn No:${invoiceProfile.fertiRegnNo.isEmpty ? '-' : invoiceProfile.fertiRegnNo}',
                                  ),
                                  _invoiceInfoCell('Cash Memo No: ${details.billNo}'),
                                ],
                              ),
                              TableRow(
                                children: [
                                  _invoiceInfoCell(
                                    'GST No:${invoiceProfile.gstNo.isEmpty ? '-' : invoiceProfile.gstNo}',
                                  ),
                                  _invoiceInfoCell(
                                    'Date: ${formatDate(DateTime.parse(details.createdAt))}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Table(
                            border: const TableBorder(
                              horizontalInside: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                              verticalInside: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1.1),
                            },
                            children: [
                              TableRow(
                                children: [
                                  _invoiceInfoCell(
                                    'Customer name - ${details.customerName.isEmpty ? '-' : details.customerName}',
                                  ),
                                  _invoiceInfoCell(
                                    'MO: ${details.mobile.isEmpty ? '-' : details.mobile}',
                                  ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  _invoiceInfoCell(
                                    'Village: ${details.village.isEmpty ? '-' : details.village}',
                                  ),
                                  _invoiceInfoCell(
                                    'District: ${details.district.isEmpty ? '-' : details.district}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Table(
                            border: const TableBorder(
                              horizontalInside: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                              verticalInside: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: AppColors.textPrimary,
                                width: 1,
                              ),
                            ),
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            columnWidths: const {
                              0: FixedColumnWidth(56),
                              1: FlexColumnWidth(2.3),
                              2: FlexColumnWidth(1.1),
                              3: FlexColumnWidth(0.9),
                              4: FixedColumnWidth(76),
                              5: FixedColumnWidth(112),
                              6: FixedColumnWidth(120),
                              7: FixedColumnWidth(98),
                              8: FixedColumnWidth(98),
                              9: FixedColumnWidth(98),
                              10: FixedColumnWidth(120),
                            },
                            children: [
                              const TableRow(
                                decoration: BoxDecoration(
                                  color: AppColors.tableHeaderBg,
                                ),
                                children: [
                                  _InvoiceHeadCell('Sr No'),
                                  _InvoiceHeadCell('Description of Goods'),
                                  _InvoiceHeadCell('HSN Code'),
                                  _InvoiceHeadCell('Pack'),
                                  _InvoiceHeadCell('Qty (Unit)', align: TextAlign.right),
                                  _InvoiceHeadCell('Unit Price (Rs.)', align: TextAlign.right),
                                  _InvoiceHeadCell(
                                    'Taxable Amt (Rs.)',
                                    align: TextAlign.right,
                                  ),
                                  _InvoiceHeadCell('GST Rate (%)', align: TextAlign.right),
                                  _InvoiceHeadCell('CGST (Rs.)', align: TextAlign.right),
                                  _InvoiceHeadCell('SGST (Rs.)', align: TextAlign.right),
                                  _InvoiceHeadCell('Net Amt (Rs.)', align: TextAlign.right),
                                ],
                              ),
                              for (var i = 0; i < details.lines.length; i++)
                                _buildInvoiceLineRow(
                                  srNo: i + 1,
                                  line: details.lines[i],
                                  gstRatePercent: details.gstRatePercent,
                                ),
                              TableRow(
                                children: [
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(''),
                                  const _InvoiceBodyCell(
                                    'TOTAL',
                                    align: TextAlign.right,
                                    bold: true,
                                  ),
                                  _InvoiceBodyCell(
                                    formatCurrency(details.grossTotal),
                                    align: TextAlign.right,
                                    bold: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.textPrimary,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Note: Fertilizers for Agriculture use only.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Signature of Customer',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'E&OE',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Text(
                                  'For ${invoiceProfile.shopName.isEmpty ? 'SHOP NAME' : invoiceProfile.shopName.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

  Widget _invoiceInfoCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  TableRow _buildInvoiceLineRow({
    required int srNo,
    required BillLineDetail line,
    required double gstRatePercent,
  }) {
    final taxableAmount = _round2(line.unitPriceAtSale * line.quantity);
    final gstAmount = _round2(taxableAmount * (gstRatePercent / 100));
    final cgst = _round2(gstAmount / 2);
    final sgst = _round2(gstAmount / 2);
    final netAmount = _round2(taxableAmount + gstAmount);

    return TableRow(
      children: [
        _InvoiceBodyCell(srNo.toString()),
        _InvoiceBodyCell(line.itemName),
        _InvoiceBodyCell(
          line.hsnCode?.trim().isNotEmpty == true ? line.hsnCode! : '-',
        ),
        _InvoiceBodyCell(_packingText(line)),
        _InvoiceBodyCell(
          line.quantity.toString(),
          align: TextAlign.right,
        ),
        _InvoiceBodyCell(
          line.unitPriceAtSale.toStringAsFixed(2),
          align: TextAlign.right,
        ),
        _InvoiceBodyCell(
          taxableAmount.toStringAsFixed(2),
          align: TextAlign.right,
        ),
        _InvoiceBodyCell(
          '${gstRatePercent.toStringAsFixed(2)}%',
          align: TextAlign.right,
        ),
        _InvoiceBodyCell(
          cgst.toStringAsFixed(2),
          align: TextAlign.right,
        ),
        _InvoiceBodyCell(
          sgst.toStringAsFixed(2),
          align: TextAlign.right,
        ),
        _InvoiceBodyCell(
          netAmount.toStringAsFixed(2),
          align: TextAlign.right,
          bold: true,
        ),
      ],
    );
  }

  String _packingText(BillLineDetail line) {
    if (line.packingWeight == null) {
      return '-';
    }
    final weight = line.packingWeight!;
    final formatted = weight % 1 == 0
        ? weight.toStringAsFixed(0)
        : weight.toStringAsFixed(2);
    final unit = line.packingUnit?.trim();
    if (unit == null || unit.isEmpty) {
      return formatted;
    }
    return '$formatted $unit';
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

class _InvoiceHeadCell extends StatelessWidget {
  const _InvoiceHeadCell(this.text, {this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _InvoiceBodyCell extends StatelessWidget {
  const _InvoiceBodyCell(
    this.text, {
    this.align = TextAlign.left,
    this.bold = false,
  });

  final String text;
  final TextAlign align;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

double _round2(double value) => (value * 100).roundToDouble() / 100;
