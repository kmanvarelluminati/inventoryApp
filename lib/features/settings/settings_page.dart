import 'dart:io';

import 'package:flutter/material.dart';

import 'package:stock_manager/data/models/entities.dart';
import 'package:stock_manager/data/services/app_database.dart';
import 'package:stock_manager/theme/app_theme.dart';
import 'package:stock_manager/widgets/desktop_page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.database,
    required this.manualPriceOverrideEnabled,
    required this.gstRatePercent,
    required this.invoiceProfile,
    required this.onManualPriceOverrideChanged,
    required this.onGstRateChanged,
    required this.onInvoiceProfileChanged,
  });

  final AppDatabase database;
  final bool manualPriceOverrideEnabled;
  final double gstRatePercent;
  final InvoiceProfileSettings invoiceProfile;
  final Future<void> Function(bool enabled) onManualPriceOverrideChanged;
  final Future<void> Function(double gstRatePercent) onGstRateChanged;
  final Future<void> Function(InvoiceProfileSettings settings)
  onInvoiceProfileChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _gstController;
  late final TextEditingController _shopNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _mobileController;
  late final TextEditingController _gstNoController;
  late final TextEditingController _fertiRegnController;
  bool _openingDatabaseLocation = false;
  bool _savingGst = false;
  bool _savingInvoiceProfile = false;

  @override
  void initState() {
    super.initState();
    _gstController = TextEditingController(
      text: _formatRate(widget.gstRatePercent),
    );
    _shopNameController = TextEditingController(text: widget.invoiceProfile.shopName);
    _addressController = TextEditingController(text: widget.invoiceProfile.address);
    _mobileController = TextEditingController(text: widget.invoiceProfile.mobile);
    _gstNoController = TextEditingController(text: widget.invoiceProfile.gstNo);
    _fertiRegnController = TextEditingController(
      text: widget.invoiceProfile.fertiRegnNo,
    );
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gstRatePercent != widget.gstRatePercent && !_savingGst) {
      _gstController.text = _formatRate(widget.gstRatePercent);
    }
    if (!_savingInvoiceProfile &&
        oldWidget.invoiceProfile != widget.invoiceProfile) {
      _shopNameController.text = widget.invoiceProfile.shopName;
      _addressController.text = widget.invoiceProfile.address;
      _mobileController.text = widget.invoiceProfile.mobile;
      _gstNoController.text = widget.invoiceProfile.gstNo;
      _fertiRegnController.text = widget.invoiceProfile.fertiRegnNo;
    }
  }

  @override
  void dispose() {
    _gstController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    _mobileController.dispose();
    _gstNoController.dispose();
    _fertiRegnController.dispose();
    super.dispose();
  }

  Future<void> _saveGstRate() async {
    final value = double.tryParse(_gstController.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid GST rate (0 or above).')),
      );
      return;
    }

    setState(() {
      _savingGst = true;
    });

    try {
      final normalized = _round2(value);
      await widget.onGstRateChanged(normalized);
      if (!mounted) {
        return;
      }
      _gstController.text = _formatRate(normalized);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('GST rate updated.')));
    } finally {
      if (mounted) {
        setState(() {
          _savingGst = false;
        });
      }
    }
  }

  Future<void> _saveInvoiceProfile() async {
    setState(() {
      _savingInvoiceProfile = true;
    });
    try {
      await widget.onInvoiceProfileChanged(
        InvoiceProfileSettings(
          shopName: _shopNameController.text,
          address: _addressController.text,
          mobile: _mobileController.text,
          gstNo: _gstNoController.text,
          fertiRegnNo: _fertiRegnController.text,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice profile updated.')));
    } finally {
      if (mounted) {
        setState(() {
          _savingInvoiceProfile = false;
        });
      }
    }
  }

  Future<void> _openDatabaseLocation() async {
    if (_openingDatabaseLocation) {
      return;
    }

    final dbPath = widget.database.databasePath;
    final dbFile = File(dbPath);
    final targetDirectory = dbFile.parent;

    setState(() {
      _openingDatabaseLocation = true;
    });

    try {
      if (!dbFile.existsSync() && !targetDirectory.existsSync()) {
        throw StateError('Database location does not exist yet.');
      }

      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,$dbPath']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', dbPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [targetDirectory.path]);
      } else {
        throw UnsupportedError('Open location is not supported here.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open DB path: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _openingDatabaseLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const DesktopPageHeader(
            title: 'Settings',
            subtitle: 'Configure application preferences',
          ),
          const SizedBox(height: 24),
          const Text(
            'BILLING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
            const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.manualPriceOverrideEnabled
                          ? AppColors.primaryLight
                          : AppColors.tableHeaderBg,
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: Icon(
                      Icons.price_change_outlined,
                      size: 18,
                      color: widget.manualPriceOverrideEnabled
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Allow Manual Price Override',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'When disabled, billing always uses the item master current price.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: widget.manualPriceOverrideEnabled,
                    activeTrackColor: AppColors.primaryLight,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) async {
                      await widget.onManualPriceOverrideChanged(value);
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings updated.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.tableHeaderBg,
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: const Icon(
                      Icons.percent,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GST Rate (%)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Used in bill calculations for GST, CGST, and SGST.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _gstController,
                      enabled: !_savingGst,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onSubmitted: (_) => _saveGstRate(),
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: '%',
                        hintText: '0.00',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _savingGst ? null : _saveGstRate,
                    child: Text(_savingGst ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
          ),
            const SizedBox(height: 20),
            const Text(
              'DATABASE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Local Database Path',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Use this only to find the local DB file on this PC.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(AppRadius.base),
                      ),
                      child: SelectableText(
                        widget.database.databasePath,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _openingDatabaseLocation
                            ? null
                            : _openDatabaseLocation,
                        icon: Icon(
                          _openingDatabaseLocation
                              ? Icons.hourglass_empty
                              : Icons.folder_open,
                          size: 16,
                        ),
                        label: Text(
                          _openingDatabaseLocation ? 'Opening...' : 'Open',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'INVOICE HEADER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _shopNameController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Shop Name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _mobileController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Mobile',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Address',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gstNoController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'GST No',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _fertiRegnController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Ferti Regn No',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _savingInvoiceProfile
                            ? null
                            : _saveInvoiceProfile,
                        child: Text(
                          _savingInvoiceProfile ? 'Saving...' : 'Save Profile',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRate(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

double _round2(double value) => (value * 100).roundToDouble() / 100;
