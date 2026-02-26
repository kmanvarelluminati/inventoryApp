class BillLineInput {
  const BillLineInput({
    required this.itemId,
    required this.quantity,
    this.manualUnitPrice,
  });

  final int itemId;
  final int quantity;
  final double? manualUnitPrice;
}

enum BillStatus { active, cancelled }

class StockAction {
  static const String openingStock = 'Opening Stock';
  static const String stockAdded = 'Stock Added';
  static const String sold = 'Sold';
  static const String priceUpdated = 'Price Updated';
  static const String stockAdjustment = 'Stock Adjustment';
}

class ItemRecord {
  const ItemRecord({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.currentPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int currentStock;
  final double currentPrice;
  final String createdAt;
  final String updatedAt;

  factory ItemRecord.fromMap(Map<String, Object?> map) {
    return ItemRecord(
      id: _intValue(map['id']),
      name: _string(map['name']),
      currentStock: _intValue(map['current_stock']),
      currentPrice: _doubleValue(map['current_price']),
      createdAt: _string(map['created_at']),
      updatedAt: _string(map['updated_at']),
    );
  }
}

class BillSummary {
  const BillSummary({
    required this.id,
    required this.billNo,
    required this.status,
    required this.grossTotal,
    required this.createdAt,
    this.cancelledAt,
  });

  final int id;
  final String billNo;
  final BillStatus status;
  final double grossTotal;
  final String createdAt;
  final String? cancelledAt;

  factory BillSummary.fromMap(Map<String, Object?> map) {
    return BillSummary(
      id: _intValue(map['id']),
      billNo: _string(map['bill_no']),
      status: BillStatus.values.byName(_string(map['status'])),
      grossTotal: _doubleValue(map['gross_total']),
      createdAt: _string(map['created_at']),
      cancelledAt: _nullableString(map['cancelled_at']),
    );
  }
}

class BillLineDetail {
  const BillLineDetail({
    required this.id,
    required this.billId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPriceAtSale,
    required this.lineTotal,
  });

  final int id;
  final int billId;
  final int itemId;
  final String itemName;
  final int quantity;
  final double unitPriceAtSale;
  final double lineTotal;

  factory BillLineDetail.fromMap(Map<String, Object?> map) {
    return BillLineDetail(
      id: _intValue(map['id']),
      billId: _intValue(map['bill_id']),
      itemId: _intValue(map['item_id']),
      itemName: _string(map['item_name']),
      quantity: _intValue(map['qty']),
      unitPriceAtSale: _doubleValue(map['unit_price_at_sale']),
      lineTotal: _doubleValue(map['line_total']),
    );
  }
}

class BillDetails {
  const BillDetails({
    required this.id,
    required this.billNo,
    required this.status,
    required this.grossTotal,
    required this.createdAt,
    required this.lines,
    this.cancelledAt,
  });

  final int id;
  final String billNo;
  final BillStatus status;
  final double grossTotal;
  final String createdAt;
  final String? cancelledAt;
  final List<BillLineDetail> lines;
}

class StockMovementRecord {
  const StockMovementRecord({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.actionType,
    required this.quantityDelta,
    required this.previousStock,
    required this.newStock,
    required this.previousPrice,
    required this.newPrice,
    required this.referenceType,
    required this.referenceId,
    required this.runningBalance,
    required this.createdAt,
  });

  final int id;
  final int itemId;
  final String itemName;
  final String actionType;
  final int quantityDelta;
  final int previousStock;
  final int newStock;
  final double? previousPrice;
  final double? newPrice;
  final String referenceType;
  final String referenceId;
  final int runningBalance;
  final String createdAt;

  factory StockMovementRecord.fromMap(Map<String, Object?> map) {
    return StockMovementRecord(
      id: _intValue(map['id']),
      itemId: _intValue(map['item_id']),
      itemName: _string(map['item_name']),
      actionType: _string(map['action_type']),
      quantityDelta: _intValue(map['qty_delta']),
      previousStock: _intValue(map['prev_stock']),
      newStock: _intValue(map['new_stock']),
      previousPrice: map['prev_price'] == null
          ? null
          : _doubleValue(map['prev_price']),
      newPrice: map['new_price'] == null
          ? null
          : _doubleValue(map['new_price']),
      referenceType: _string(map['ref_type']),
      referenceId: _string(map['ref_id']),
      runningBalance: _intValue(map['running_balance']),
      createdAt: _string(map['created_at']),
    );
  }
}

class SummaryTotals {
  const SummaryTotals({
    required this.totalBills,
    required this.totalItemsSold,
    required this.totalSalesAmount,
  });

  final int totalBills;
  final int totalItemsSold;
  final double totalSalesAmount;
}

class DailySummaryRecord {
  const DailySummaryRecord({
    required this.day,
    required this.totalBills,
    required this.totalItemsSold,
    required this.totalSalesAmount,
  });

  final String day;
  final int totalBills;
  final int totalItemsSold;
  final double totalSalesAmount;

  factory DailySummaryRecord.fromMap(Map<String, Object?> map) {
    return DailySummaryRecord(
      day: _string(map['day']),
      totalBills: _intValue(map['total_bills']),
      totalItemsSold: _intValue(map['total_items_sold']),
      totalSalesAmount: _doubleValue(map['total_sales_amount']),
    );
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
