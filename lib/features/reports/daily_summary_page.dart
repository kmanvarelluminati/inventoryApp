import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/theme/app_theme.dart';
import 'package:stock_manager/utils/formatters.dart';
import 'package:stock_manager/widgets/desktop_page_header.dart';

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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Reports',
            subtitle: 'Sales analytics and daily breakdown',
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
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary cards
                  Row(
                    children: [
                      _SummaryCard(
                        icon: Icons.receipt_outlined,
                        label: 'Total Bills',
                        value: _totals.totalBills.toString(),
                      ),
                      const SizedBox(width: 16),
                      _SummaryCard(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Items Sold',
                        value: _totals.totalItemsSold.toString(),
                      ),
                      const SizedBox(width: 16),
                      _SummaryCard(
                        icon: Icons.attach_money,
                        label: 'Total Sales',
                        value: formatCurrency(_totals.totalSalesAmount),
                        highlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section label
                  const Text(
                    'DATE-WISE BREAKDOWN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Daily breakdown table
                  Expanded(
                    child: _dailyRows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bar_chart_outlined,
                                  size: 48,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No data for selected period',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
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
                                      _tableHeader('Date', flex: 3),
                                      _tableHeader('Bills', flex: 2, align: TextAlign.right),
                                      _tableHeader('Items Sold', flex: 2, align: TextAlign.right),
                                      _tableHeader('Sales Amount', flex: 3, align: TextAlign.right),
                                    ],
                                  ),
                                ),
                                Container(height: 1, color: AppColors.border),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _dailyRows.length,
                                    separatorBuilder: (_, _) =>
                                        Container(height: 1, color: AppColors.borderLight),
                                    itemBuilder: (context, index) {
                                      final row = _dailyRows[index];
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
                                                row.day,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                row.totalBills.toString(),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                row.totalItemsSold.toString(),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                formatCurrency(row.totalSalesAmount),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: highlight ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: highlight ? AppColors.primaryLight : AppColors.tableHeaderBg,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: highlight ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
