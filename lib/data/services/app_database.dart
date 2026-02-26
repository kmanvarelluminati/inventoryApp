import 'dart:io';
import 'dart:math';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:stock_manager/data/models/entities.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;
    final dbDirectory = await dbFactory.getDatabasesPath();
    final dbPath = '$dbDirectory${Platform.pathSeparator}inventory_billing.db';

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON;');
          await database.execute('PRAGMA journal_mode = WAL;');
        },
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              current_stock INTEGER NOT NULL CHECK (current_stock >= 0),
              current_price REAL NOT NULL CHECK (current_price >= 0),
              barcode TEXT,
              low_stock_threshold INTEGER,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');

          await database.execute('''
            CREATE TABLE stock_ledger (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              item_id INTEGER NOT NULL,
              action_type TEXT NOT NULL,
              qty_delta INTEGER NOT NULL,
              prev_stock INTEGER NOT NULL CHECK (prev_stock >= 0),
              new_stock INTEGER NOT NULL CHECK (new_stock >= 0),
              prev_price REAL,
              new_price REAL,
              ref_type TEXT NOT NULL,
              ref_id TEXT NOT NULL,
              running_balance INTEGER NOT NULL CHECK (running_balance >= 0),
              created_at TEXT NOT NULL,
              FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE RESTRICT
            );
          ''');

          await database.execute(
            'CREATE INDEX idx_stock_ledger_item_time ON stock_ledger(item_id, created_at DESC);',
          );

          await database.execute('''
            CREATE TABLE bills (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              bill_no TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL CHECK (status IN ('active', 'cancelled')),
              gross_total REAL NOT NULL CHECK (gross_total >= 0),
              created_at TEXT NOT NULL,
              cancelled_at TEXT
            );
          ''');

          await database.execute('''
            CREATE TABLE bill_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              bill_id INTEGER NOT NULL,
              item_id INTEGER NOT NULL,
              qty INTEGER NOT NULL CHECK (qty > 0),
              unit_price_at_sale REAL NOT NULL CHECK (unit_price_at_sale >= 0),
              line_total REAL NOT NULL CHECK (line_total >= 0),
              FOREIGN KEY(bill_id) REFERENCES bills(id) ON DELETE RESTRICT,
              FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE RESTRICT
            );
          ''');

          await database.execute(
            'CREATE INDEX idx_bill_items_bill ON bill_items(bill_id);',
          );

          await database.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
          ''');

          await database.insert('app_settings', {
            'key': 'manual_price_override',
            'value': '0',
          });
        },
      ),
    );

    await db.insert('app_settings', {
      'key': 'manual_price_override',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return AppDatabase._(db);
  }

  Future<List<ItemRecord>> getItems() async {
    final rows = await _db.query('items', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(ItemRecord.fromMap).toList();
  }

  Future<bool> getManualPriceOverrideEnabled() async {
    final rows = await _db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['manual_price_override'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    return _string(rows.first['value']) == '1';
  }

  Future<void> setManualPriceOverrideEnabled(bool enabled) async {
    await _db.insert('app_settings', {
      'key': 'manual_price_override',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> createItem({
    required String name,
    required int openingQuantity,
    required double currentPrice,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Item name cannot be empty.');
    }
    if (openingQuantity < 0) {
      throw ArgumentError('Opening quantity cannot be negative.');
    }
    if (currentPrice < 0) {
      throw ArgumentError('Current price cannot be negative.');
    }

    final now = _nowIso();

    await _db.transaction((txn) async {
      final itemId = await txn.insert('items', {
        'name': name.trim(),
        'current_stock': openingQuantity,
        'current_price': currentPrice,
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('stock_ledger', {
        'item_id': itemId,
        'action_type': StockAction.openingStock,
        'qty_delta': openingQuantity,
        'prev_stock': 0,
        'new_stock': openingQuantity,
        'prev_price': null,
        'new_price': currentPrice,
        'ref_type': 'item',
        'ref_id': 'ITEM-$itemId',
        'running_balance': openingQuantity,
        'created_at': now,
      });
    });
  }

  Future<void> addStock({required int itemId, required int quantity}) async {
    if (quantity <= 0) {
      throw ArgumentError('Stock add quantity must be greater than zero.');
    }

    final now = _nowIso();

    await _db.transaction((txn) async {
      final item = await _getItemById(txn, itemId);
      if (item == null) {
        throw StateError('Item not found.');
      }

      final previousStock = item.currentStock;
      final newStock = previousStock + quantity;

      final updateCount = await txn.update(
        'items',
        {'current_stock': newStock, 'updated_at': now},
        where: 'id = ? AND current_stock = ?',
        whereArgs: [itemId, previousStock],
      );
      if (updateCount != 1) {
        throw StateError('Concurrent stock update detected.');
      }

      await txn.insert('stock_ledger', {
        'item_id': itemId,
        'action_type': StockAction.stockAdded,
        'qty_delta': quantity,
        'prev_stock': previousStock,
        'new_stock': newStock,
        'prev_price': item.currentPrice,
        'new_price': item.currentPrice,
        'ref_type': 'stock',
        'ref_id': 'STK-${DateTime.now().millisecondsSinceEpoch}',
        'running_balance': newStock,
        'created_at': now,
      });
    });
  }

  Future<void> updateItemPrice({
    required int itemId,
    required double newPrice,
  }) async {
    if (newPrice < 0) {
      throw ArgumentError('Price cannot be negative.');
    }

    final now = _nowIso();

    await _db.transaction((txn) async {
      final item = await _getItemById(txn, itemId);
      if (item == null) {
        throw StateError('Item not found.');
      }

      final oldPrice = item.currentPrice;
      if (oldPrice == newPrice) {
        return;
      }

      final updateCount = await txn.update(
        'items',
        {'current_price': newPrice, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (updateCount != 1) {
        throw StateError('Failed to update item price.');
      }

      await txn.insert('stock_ledger', {
        'item_id': itemId,
        'action_type': StockAction.priceUpdated,
        'qty_delta': 0,
        'prev_stock': item.currentStock,
        'new_stock': item.currentStock,
        'prev_price': oldPrice,
        'new_price': newPrice,
        'ref_type': 'price',
        'ref_id': 'PRC-${DateTime.now().millisecondsSinceEpoch}',
        'running_balance': item.currentStock,
        'created_at': now,
      });
    });
  }

  Future<String> createBill(
    List<BillLineInput> lines, {
    required bool manualPriceOverrideEnabled,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Bill must contain at least one line item.');
    }

    final seen = <int>{};
    for (final line in lines) {
      if (line.quantity <= 0) {
        throw ArgumentError('Bill item quantity must be positive.');
      }
      if (!seen.add(line.itemId)) {
        throw ArgumentError('Duplicate items in bill are not allowed.');
      }
    }

    final now = _nowIso();

    return _db.transaction<String>((txn) async {
      final itemsById = <int, ItemRecord>{};
      for (final line in lines) {
        final item = await _getItemById(txn, line.itemId);
        if (item == null) {
          throw StateError('Item not found: ${line.itemId}');
        }

        if (item.currentStock < line.quantity) {
          throw StateError(
            'Insufficient stock for ${item.name}. Available: ${item.currentStock}, requested: ${line.quantity}.',
          );
        }

        itemsById[line.itemId] = item;
      }

      final billNo = await _generateBillNo(txn);
      final billId = await txn.insert('bills', {
        'bill_no': billNo,
        'status': BillStatus.active.name,
        'gross_total': 0,
        'created_at': now,
        'cancelled_at': null,
      });

      var grossTotal = 0.0;
      final currentStocks = <int, int>{
        for (final entry in itemsById.entries)
          entry.key: entry.value.currentStock,
      };

      for (final line in lines) {
        final item = itemsById[line.itemId]!;
        final previousStock = currentStocks[line.itemId]!;
        final newStock = previousStock - line.quantity;
        if (newStock < 0) {
          throw StateError('Stock cannot go below zero.');
        }

        final chosenPrice =
            manualPriceOverrideEnabled && line.manualUnitPrice != null
            ? line.manualUnitPrice!
            : item.currentPrice;

        if (chosenPrice < 0) {
          throw StateError('Sale price cannot be negative.');
        }

        final lineTotal = chosenPrice * line.quantity;
        grossTotal += lineTotal;

        final updateCount = await txn.update(
          'items',
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ? AND current_stock = ?',
          whereArgs: [line.itemId, previousStock],
        );

        if (updateCount != 1) {
          throw StateError(
            'Concurrent stock update detected for item: ${item.name}',
          );
        }

        currentStocks[line.itemId] = newStock;

        await txn.insert('bill_items', {
          'bill_id': billId,
          'item_id': line.itemId,
          'qty': line.quantity,
          'unit_price_at_sale': chosenPrice,
          'line_total': lineTotal,
        });

        await txn.insert('stock_ledger', {
          'item_id': line.itemId,
          'action_type': StockAction.sold,
          'qty_delta': -line.quantity,
          'prev_stock': previousStock,
          'new_stock': newStock,
          'prev_price': item.currentPrice,
          'new_price': item.currentPrice,
          'ref_type': 'bill',
          'ref_id': billNo,
          'running_balance': newStock,
          'created_at': now,
        });
      }

      await txn.update(
        'bills',
        {'gross_total': grossTotal},
        where: 'id = ?',
        whereArgs: [billId],
      );

      return billNo;
    });
  }

  Future<List<BillSummary>> getBills({
    DateTime? startDateInclusive,
    DateTime? endDateExclusive,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];

    if (startDateInclusive != null) {
      clauses.add('created_at >= ?');
      args.add(startDateInclusive.toIso8601String());
    }

    if (endDateExclusive != null) {
      clauses.add('created_at < ?');
      args.add(endDateExclusive.toIso8601String());
    }

    final rows = await _db.query(
      'bills',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );

    return rows.map(BillSummary.fromMap).toList();
  }

  Future<BillDetails> getBillDetails(int billId) async {
    final billRows = await _db.query(
      'bills',
      where: 'id = ?',
      whereArgs: [billId],
      limit: 1,
    );

    if (billRows.isEmpty) {
      throw StateError('Bill not found.');
    }

    final bill = billRows.first;

    final lineRows = await _db.rawQuery(
      '''
      SELECT
        bi.id,
        bi.bill_id,
        bi.item_id,
        i.name AS item_name,
        bi.qty,
        bi.unit_price_at_sale,
        bi.line_total
      FROM bill_items bi
      JOIN items i ON i.id = bi.item_id
      WHERE bi.bill_id = ?
      ORDER BY bi.id ASC
      ''',
      [billId],
    );

    return BillDetails(
      id: _intValue(bill['id']),
      billNo: _string(bill['bill_no']),
      status: BillStatus.values.byName(_string(bill['status'])),
      grossTotal: _doubleValue(bill['gross_total']),
      createdAt: _string(bill['created_at']),
      cancelledAt: _nullableString(bill['cancelled_at']),
      lines: lineRows.map(BillLineDetail.fromMap).toList(),
    );
  }

  Future<void> cancelBill(int billId) async {
    final now = _nowIso();

    await _db.transaction((txn) async {
      final billRows = await txn.query(
        'bills',
        where: 'id = ?',
        whereArgs: [billId],
        limit: 1,
      );

      if (billRows.isEmpty) {
        throw StateError('Bill not found.');
      }

      final bill = billRows.first;
      final status = BillStatus.values.byName(_string(bill['status']));
      if (status == BillStatus.cancelled) {
        throw StateError('Bill is already cancelled.');
      }

      final billNo = _string(bill['bill_no']);

      final lineRows = await txn.rawQuery(
        '''
        SELECT
          bi.item_id,
          bi.qty,
          i.name AS item_name,
          i.current_stock,
          i.current_price
        FROM bill_items bi
        JOIN items i ON i.id = bi.item_id
        WHERE bi.bill_id = ?
        ORDER BY bi.id ASC
        ''',
        [billId],
      );

      for (final row in lineRows) {
        final itemId = _intValue(row['item_id']);
        final quantity = _intValue(row['qty']);
        final previousStock = _intValue(row['current_stock']);
        final newStock = previousStock + quantity;
        final currentPrice = _doubleValue(row['current_price']);

        final updateCount = await txn.update(
          'items',
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ? AND current_stock = ?',
          whereArgs: [itemId, previousStock],
        );

        if (updateCount != 1) {
          throw StateError('Concurrent stock update detected during cancel.');
        }

        await txn.insert('stock_ledger', {
          'item_id': itemId,
          'action_type': StockAction.stockAdjustment,
          'qty_delta': quantity,
          'prev_stock': previousStock,
          'new_stock': newStock,
          'prev_price': currentPrice,
          'new_price': currentPrice,
          'ref_type': 'bill_cancel',
          'ref_id': billNo,
          'running_balance': newStock,
          'created_at': now,
        });
      }

      await txn.update(
        'bills',
        {'status': BillStatus.cancelled.name, 'cancelled_at': now},
        where: 'id = ?',
        whereArgs: [billId],
      );
    });
  }

  Future<List<StockMovementRecord>> getStockMovements({int? itemId}) async {
    final rows = await _db.rawQuery('''
      SELECT
        sl.id,
        sl.item_id,
        i.name AS item_name,
        sl.action_type,
        sl.qty_delta,
        sl.prev_stock,
        sl.new_stock,
        sl.prev_price,
        sl.new_price,
        sl.ref_type,
        sl.ref_id,
        sl.running_balance,
        sl.created_at
      FROM stock_ledger sl
      JOIN items i ON i.id = sl.item_id
      ${itemId == null ? '' : 'WHERE sl.item_id = ?'}
      ORDER BY sl.created_at DESC, sl.id DESC
      ''', itemId == null ? null : [itemId]);

    return rows.map(StockMovementRecord.fromMap).toList();
  }

  Future<SummaryTotals> getSummaryTotals({
    DateTime? startDateInclusive,
    DateTime? endDateExclusive,
  }) async {
    final clauses = <String>['b.status = ?'];
    final args = <Object?>[BillStatus.active.name];

    if (startDateInclusive != null) {
      clauses.add('b.created_at >= ?');
      args.add(startDateInclusive.toIso8601String());
    }

    if (endDateExclusive != null) {
      clauses.add('b.created_at < ?');
      args.add(endDateExclusive.toIso8601String());
    }

    final rows = await _db.rawQuery('''
      SELECT
        COUNT(DISTINCT b.id) AS total_bills,
        COALESCE(SUM(bi.qty), 0) AS total_items_sold,
        COALESCE(SUM(bi.line_total), 0) AS total_sales_amount
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE ${clauses.join(' AND ')}
      ''', args);

    final row = rows.first;
    return SummaryTotals(
      totalBills: _intValue(row['total_bills']),
      totalItemsSold: _intValue(row['total_items_sold']),
      totalSalesAmount: _doubleValue(row['total_sales_amount']),
    );
  }

  Future<List<DailySummaryRecord>> getDailySummaries({
    DateTime? startDateInclusive,
    DateTime? endDateExclusive,
  }) async {
    final clauses = <String>['b.status = ?'];
    final args = <Object?>[BillStatus.active.name];

    if (startDateInclusive != null) {
      clauses.add('b.created_at >= ?');
      args.add(startDateInclusive.toIso8601String());
    }

    if (endDateExclusive != null) {
      clauses.add('b.created_at < ?');
      args.add(endDateExclusive.toIso8601String());
    }

    final rows = await _db.rawQuery('''
      SELECT
        SUBSTR(b.created_at, 1, 10) AS day,
        COUNT(DISTINCT b.id) AS total_bills,
        COALESCE(SUM(bi.qty), 0) AS total_items_sold,
        COALESCE(SUM(bi.line_total), 0) AS total_sales_amount
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE ${clauses.join(' AND ')}
      GROUP BY SUBSTR(b.created_at, 1, 10)
      ORDER BY day DESC
      ''', args);

    return rows.map(DailySummaryRecord.fromMap).toList();
  }

  Future<ItemRecord?> _getItemById(DatabaseExecutor db, int itemId) async {
    final rows = await db.query('items', where: 'id = ?', whereArgs: [itemId]);
    if (rows.isEmpty) {
      return null;
    }
    return ItemRecord.fromMap(rows.first);
  }

  Future<String> _generateBillNo(DatabaseExecutor db) async {
    final random = Random();

    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate =
          'B${DateTime.now().millisecondsSinceEpoch}${100 + random.nextInt(900)}';

      final exists = await db.query(
        'bills',
        columns: ['id'],
        where: 'bill_no = ?',
        whereArgs: [candidate],
        limit: 1,
      );

      if (exists.isEmpty) {
        return candidate;
      }
    }

    throw StateError('Failed to generate unique bill number.');
  }
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.parse(value.toString());
}

double _doubleValue(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
}

String _string(Object? value) {
  return value?.toString() ?? '';
}

String? _nullableString(Object? value) {
  return value?.toString();
}

String _nowIso() => DateTime.now().toIso8601String();
