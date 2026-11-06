// Plain data classes mapped from Supabase rows.

double _d(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.parse(v.toString()));
int _i(Object? v) => v == null ? 0 : (v is num ? v.toInt() : int.parse(v.toString()));
DateTime _t(Object? v) => DateTime.parse(v as String).toUtc();
DateTime? _tn(Object? v) => v == null ? null : _t(v);

class Roles {
  static const admin = 'admin';
  static const orderTaker = 'order_taker';
}

class OrderStatus {
  static const submitted = 'Submitted';
  static const delivered = 'Delivered';
  static const cancelled = 'Cancelled';
  static const all = [submitted, delivered, cancelled];
}

class AppUser {
  final String id;
  final String userId;
  final String fullName;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.createdAt,
  });

  bool get isAdmin => role == Roles.admin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        fullName: j['full_name'] as String,
        role: j['role'] as String,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: _tn(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'full_name': fullName,
        'role': role,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };
}

class RoleInfo {
  final String code;
  final String label;
  const RoleInfo(this.code, this.label);
  factory RoleInfo.fromJson(Map<String, dynamic> j) => RoleInfo(j['code'] as String, j['label'] as String);
}

class Product {
  final String id;
  final String name;
  final String unit;
  final double defaultRate;
  final bool isActive;

  const Product({required this.id, required this.name, required this.unit, required this.defaultRate, required this.isActive});

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        defaultRate: _d(j['default_rate']),
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'unit': unit, 'default_rate': defaultRate, 'is_active': isActive};
}

class Vehicle {
  final String id;
  final String vehicleNumber;
  final String? label;
  final bool isActive;

  const Vehicle({required this.id, required this.vehicleNumber, this.label, required this.isActive});

  String get display => (label == null || label!.isEmpty) ? vehicleNumber : '$vehicleNumber · $label';

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        vehicleNumber: j['vehicle_number'] as String,
        label: j['label'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'vehicle_number': vehicleNumber, 'label': label, 'is_active': isActive};
}

class Party {
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? address;
  final bool isActive;

  const Party({required this.id, required this.name, this.contactName, this.phone, this.address, required this.isActive});

  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: j['id'] as String,
        name: j['name'] as String,
        contactName: j['contact_name'] as String?,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contact_name': contactName,
        'phone': phone,
        'address': address,
        'is_active': isActive,
      };
}

class PartyRate {
  final String? id;
  final String partyId;
  final String productId;
  final double rate;
  final DateTime effectiveFrom; // date only
  final DateTime? createdAt;
  final String? createdBy;

  const PartyRate({
    this.id,
    required this.partyId,
    required this.productId,
    required this.rate,
    required this.effectiveFrom,
    this.createdAt,
    this.createdBy,
  });

  factory PartyRate.fromJson(Map<String, dynamic> j) => PartyRate(
        id: j['id'] as String?,
        partyId: j['party_id'] as String,
        productId: j['product_id'] as String,
        rate: _d(j['rate']),
        effectiveFrom: DateTime.parse(j['effective_from'] as String),
        createdAt: _tn(j['created_at']),
        createdBy: j['created_by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'party_id': partyId,
        'product_id': productId,
        'rate': rate,
        'effective_from': effectiveFrom.toIso8601String().substring(0, 10),
      };
}

/// One product line on the order form or a queued order.
class OrderLineInput {
  final String productId;
  final int quantity;
  const OrderLineInput(this.productId, this.quantity);

  Map<String, dynamic> toJson() => {'product_id': productId, 'quantity': quantity};
  factory OrderLineInput.fromJson(Map<String, dynamic> j) =>
      OrderLineInput(j['product_id'] as String, _i(j['quantity']));
}

/// An order captured on the phone that has not reached the server yet.
class PendingOrder {
  final String id; // client-generated UUID → idempotent submit
  final String partyId;
  final String? vehicleId;
  final String? notes;
  final List<OrderLineInput> items;
  final DateTime orderDatetime; // UTC, captured at submit
  final double estimatedTotal;
  final String? lastError; // server rejected it; needs attention

  const PendingOrder({
    required this.id,
    required this.partyId,
    required this.vehicleId,
    required this.notes,
    required this.items,
    required this.orderDatetime,
    required this.estimatedTotal,
    this.lastError,
  });

  PendingOrder withError(String? e) => PendingOrder(
        id: id,
        partyId: partyId,
        vehicleId: vehicleId,
        notes: notes,
        items: items,
        orderDatetime: orderDatetime,
        estimatedTotal: estimatedTotal,
        lastError: e,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'party_id': partyId,
        'vehicle_id': vehicleId,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
        'order_datetime': orderDatetime.toIso8601String(),
        'estimated_total': estimatedTotal,
        'last_error': lastError,
      };

  factory PendingOrder.fromJson(Map<String, dynamic> j) => PendingOrder(
        id: j['id'] as String,
        partyId: j['party_id'] as String,
        vehicleId: j['vehicle_id'] as String?,
        notes: j['notes'] as String?,
        items: (j['items'] as List).map((e) => OrderLineInput.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        orderDatetime: _t(j['order_datetime']),
        estimatedTotal: _d(j['estimated_total']),
        lastError: j['last_error'] as String?,
      );
}

/// Row from search_orders().
class OrderSummary {
  final String id;
  final String orderNo;
  final DateTime orderDatetime;
  final String partyId;
  final String partyName;
  final String? vehicleId;
  final String? vehicleNumber;
  final String? vehicleLabel;
  final String? notes;
  final String status;
  final int totalQuantity;
  final double totalAmount;
  final String? productsSummary;
  final String createdBy;
  final String? createdByName;
  final int totalCount;

  const OrderSummary({
    required this.id,
    required this.orderNo,
    required this.orderDatetime,
    required this.partyId,
    required this.partyName,
    this.vehicleId,
    this.vehicleNumber,
    this.vehicleLabel,
    this.notes,
    required this.status,
    required this.totalQuantity,
    required this.totalAmount,
    this.productsSummary,
    required this.createdBy,
    this.createdByName,
    required this.totalCount,
  });

  String? get vehicleDisplay => vehicleNumber == null
      ? null
      : (vehicleLabel == null || vehicleLabel!.isEmpty ? vehicleNumber : '$vehicleNumber · $vehicleLabel');

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        id: j['id'] as String,
        orderNo: j['order_no'] as String,
        orderDatetime: _t(j['order_datetime']),
        partyId: j['party_id'] as String,
        partyName: j['party_name'] as String,
        vehicleId: j['vehicle_id'] as String?,
        vehicleNumber: j['vehicle_number'] as String?,
        vehicleLabel: j['vehicle_label'] as String?,
        notes: j['notes'] as String?,
        status: j['status'] as String,
        totalQuantity: _i(j['total_quantity']),
        totalAmount: _d(j['total_amount']),
        productsSummary: j['products_summary'] as String?,
        createdBy: j['created_by'] as String,
        createdByName: j['created_by_name'] as String?,
        totalCount: _i(j['total_count']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_no': orderNo,
        'order_datetime': orderDatetime.toIso8601String(),
        'party_id': partyId,
        'party_name': partyName,
        'vehicle_id': vehicleId,
        'vehicle_number': vehicleNumber,
        'vehicle_label': vehicleLabel,
        'notes': notes,
        'status': status,
        'total_quantity': totalQuantity,
        'total_amount': totalAmount,
        'products_summary': productsSummary,
        'created_by': createdBy,
        'created_by_name': createdByName,
        'total_count': totalCount,
      };
}

class OrderItem {
  final String productId;
  final String productName;
  final String unit;
  final int quantity;
  final double rate;
  final double amount;
  final bool isDefaultRate;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.isDefaultRate,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    final p = j['products'] as Map<String, dynamic>?;
    return OrderItem(
      productId: j['product_id'] as String,
      productName: p?['name'] as String? ?? '?',
      unit: p?['unit'] as String? ?? '',
      quantity: _i(j['quantity']),
      rate: _d(j['rate']),
      amount: _d(j['amount']),
      isDefaultRate: j['is_default_rate'] as bool? ?? false,
    );
  }
}

class StatusChange {
  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;
  final String? changedByName;
  const StatusChange(this.fromStatus, this.toStatus, this.changedAt, this.changedByName);
}

class OrderDetail {
  final String id;
  final String orderNo;
  final DateTime orderDatetime;
  final String partyId;
  final String partyName;
  final String? vehicleId;
  final String? vehicleDisplay;
  final String? notes;
  final String status;
  final int totalQuantity;
  final double totalAmount;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedByName;
  final List<OrderItem> items;
  final List<StatusChange> history;

  const OrderDetail({
    required this.id,
    required this.orderNo,
    required this.orderDatetime,
    required this.partyId,
    required this.partyName,
    this.vehicleId,
    this.vehicleDisplay,
    this.notes,
    required this.status,
    required this.totalQuantity,
    required this.totalAmount,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.updatedByName,
    required this.items,
    required this.history,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final v = j['vehicles'] as Map<String, dynamic>?;
    final label = v?['label'] as String?;
    final items = ((j['order_items'] as List?) ?? [])
        .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.productName.compareTo(b.productName));
    final history = ((j['order_status_log'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return StatusChange(m['from_status'] as String?, m['to_status'] as String, _t(m['changed_at']),
          (m['changer'] as Map?)?['full_name'] as String?);
    }).toList()
      ..sort((a, b) => a.changedAt.compareTo(b.changedAt));
    return OrderDetail(
      id: j['id'] as String,
      orderNo: j['order_no'] as String,
      orderDatetime: _t(j['order_datetime']),
      partyId: j['party_id'] as String,
      partyName: (j['parties'] as Map?)?['name'] as String? ?? '?',
      vehicleId: j['vehicle_id'] as String?,
      vehicleDisplay: v == null ? null : (label == null || label.isEmpty ? v['vehicle_number'] as String : '${v['vehicle_number']} · $label'),
      notes: j['notes'] as String?,
      status: j['status'] as String,
      totalQuantity: _i(j['total_quantity']),
      totalAmount: _d(j['total_amount']),
      createdBy: j['created_by'] as String,
      createdByName: (j['creator'] as Map?)?['full_name'] as String?,
      createdAt: _t(j['created_at']),
      updatedAt: _t(j['updated_at']),
      updatedByName: (j['updater'] as Map?)?['full_name'] as String?,
      items: items,
      history: history,
    );
  }
}

/// Row from order_totals().
class TotalRow {
  final String key;
  final String label;
  final int orderCount;
  final int totalQuantity;
  final double totalAmount;
  const TotalRow(this.key, this.label, this.orderCount, this.totalQuantity, this.totalAmount);
  factory TotalRow.fromJson(Map<String, dynamic> j) => TotalRow(j['group_key'] as String, j['group_label'] as String,
      _i(j['order_count']), _i(j['total_quantity']), _d(j['total_amount']));
}

/// Filters for search_orders / order_totals / export. Matches filter_orders() in SQL.
class OrderFilters {
  final DateTime? fromDate; // plant-local date
  final DateTime? toDate;
  final String? partyId;
  final String? productId;
  final String? vehicleId; // 'none' = No vehicle
  final String? userId;
  final String? status;
  final String? search;

  const OrderFilters({this.fromDate, this.toDate, this.partyId, this.productId, this.vehicleId, this.userId, this.status, this.search});

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);

  Map<String, dynamic> toJson() => {
        if (fromDate != null) 'from_date': _date(fromDate!),
        if (toDate != null) 'to_date': _date(toDate!),
        if (partyId != null) 'party_ids': [partyId],
        if (productId != null) 'product_ids': [productId],
        if (vehicleId != null) 'vehicle_ids': [vehicleId],
        if (userId != null) 'user_ids': [userId],
        if (status != null) 'statuses': [status],
        if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
      };

  OrderFilters copyWith({
    Object? fromDate = _keep,
    Object? toDate = _keep,
    Object? partyId = _keep,
    Object? productId = _keep,
    Object? vehicleId = _keep,
    Object? userId = _keep,
    Object? status = _keep,
    Object? search = _keep,
  }) =>
      OrderFilters(
        fromDate: fromDate == _keep ? this.fromDate : fromDate as DateTime?,
        toDate: toDate == _keep ? this.toDate : toDate as DateTime?,
        partyId: partyId == _keep ? this.partyId : partyId as String?,
        productId: productId == _keep ? this.productId : productId as String?,
        vehicleId: vehicleId == _keep ? this.vehicleId : vehicleId as String?,
        userId: userId == _keep ? this.userId : userId as String?,
        status: status == _keep ? this.status : status as String?,
        search: search == _keep ? this.search : search as String?,
      );
}

const _keep = Object();
