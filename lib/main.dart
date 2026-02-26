import 'dart:io';

import 'package:flutter/material.dart';

import 'package:stock_manager/core/inventory_billing_app.dart';
import 'package:stock_manager/core/unsupported_platform_app.dart';
import 'package:stock_manager/data/services/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows && !Platform.isMacOS) {
    runApp(const UnsupportedPlatformApp());
    return;
  }

  final db = await AppDatabase.open();
  runApp(InventoryBillingApp(database: db));
}
