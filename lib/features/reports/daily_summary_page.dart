import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Reports',
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
