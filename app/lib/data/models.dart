// Plain data classes mapped from Supabase rows.

double _d(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.parse(v.toString()));
int _i(Object? v) => v == null ? 0 : (v is num ? v.toInt() : int.parse(v.toString()));
DateTime _t(Object? v) => DateTime.parse(v as String).toUtc();
DateTime? _tn(Object? v) => v == null ? null : _t(v);

class Roles {
  static const admin = 'admin';
  static const orderTaker = 'order_taker';
}

class InvoiceCategory {
  static const general = 'general';
  static const gst = 'gst';
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
  final String? hsnCode;
  final bool isActive;

  const Product({required this.id, required this.name, required this.unit, required this.defaultRate, this.hsnCode, required this.isActive});

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        defaultRate: _d(j['default_rate']),
        hsnCode: j['hsn_code'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'unit': unit, 'default_rate': defaultRate, 'hsn_code': hsnCode, 'is_active': isActive};
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

class Driver {
  final String id;
  final String name;
  final String? phone;
  final bool isActive;

  const Driver({required this.id, required this.name, this.phone, required this.isActive});

  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'is_active': isActive};
}

/// Company details and invoice series (single row in app_settings).
class AppSettings {
  final String companyName;
  final String? companyAddress;
  final String? companyGstin;
  final String? companyPan;
  final String? companyPhone;
  final String? jurisdiction;
  final double gstRate;
  final String gstInvoiceFormat;
  final int gstNextNo;
  final String generalInvoiceFormat;
  final int generalNextNo;

  const AppSettings({
    required this.companyName,
    this.companyAddress,
    this.companyGstin,
    this.companyPan,
    this.companyPhone,
    this.jurisdiction,
    required this.gstRate,
    required this.gstInvoiceFormat,
    required this.gstNextNo,
    required this.generalInvoiceFormat,
    required this.generalNextNo,
  });

  static const fallback = AppSettings(
    companyName: 'PARKAR WATER PRODUCTS',
    gstRate: 5,
    gstInvoiceFormat: '{n}/PWP/{fy}',
    gstNextNo: 1,
    generalInvoiceFormat: '{n}',
    generalNextNo: 1,
  );

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        companyName: j['company_name'] as String,
        companyAddress: j['company_address'] as String?,
        companyGstin: j['company_gstin'] as String?,
        companyPan: j['company_pan'] as String?,
        companyPhone: j['company_phone'] as String?,
        jurisdiction: j['jurisdiction'] as String?,
        gstRate: _d(j['gst_rate']),
        gstInvoiceFormat: j['gst_invoice_format'] as String,
        gstNextNo: _i(j['gst_next_no']),
        generalInvoiceFormat: j['general_invoice_format'] as String,
        generalNextNo: _i(j['general_next_no']),
      );

  Map<String, dynamic> toJson() => {
        'company_name': companyName,
        'company_address': companyAddress,
        'company_gstin': companyGstin,
        'company_pan': companyPan,
        'company_phone': companyPhone,
        'jurisdiction': jurisdiction,
        'gst_rate': gstRate,
        'gst_invoice_format': gstInvoiceFormat,
        'gst_next_no': gstNextNo,
        'general_invoice_format': generalInvoiceFormat,
        'general_next_no': generalNextNo,
      };
}

class Party {
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? address;
  final String? gstin;
  final bool isActive;

  const Party({required this.id, required this.name, this.contactName, this.phone, this.address, this.gstin, required this.isActive});

  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: j['id'] as String,
        name: j['name'] as String,
        contactName: j['contact_name'] as String?,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        gstin: j['gstin'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contact_name': contactName,
        'phone': phone,
        'address': address,
        'gstin': gstin,
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

  /// Set only when the order taker overrode the rate.
  final double? rate;
  const OrderLineInput(this.productId, this.quantity, {this.rate});

  Map<String, dynamic> toJson() => {'product_id': productId, 'quantity': quantity, if (rate != null) 'rate': rate};
  factory OrderLineInput.fromJson(Map<String, dynamic> j) =>
      OrderLineInput(j['product_id'] as String, _i(j['quantity']), rate: j['rate'] == null ? null : _d(j['rate']));
}

/// An order captured on the phone that has not reached the server yet.
class PendingOrder {
  final String id; // client-generated UUID → idempotent submit
  final String partyId;
  final String? vehicleId;
  final String? driverId;
  final String invoiceCategory;
  final String? notes;
  final List<OrderLineInput> items;
  final DateTime orderDatetime; // UTC, captured at submit
  final double estimatedTotal;
  final String? lastError; // server rejected it; needs attention

  const PendingOrder({
    required this.id,
    required this.partyId,
    required this.vehicleId,
    this.driverId,
    this.invoiceCategory = InvoiceCategory.general,
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
        driverId: driverId,
        invoiceCategory: invoiceCategory,
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
        'driver_id': driverId,
        'invoice_category': invoiceCategory,
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
        driverId: j['driver_id'] as String?,
        invoiceCategory: j['invoice_category'] as String? ?? InvoiceCategory.general,
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
  final String invoiceNo;
  final String invoiceCategory;
  final String? driverId;
  final String? driverName;
  final double subtotal;
  final double gstAmount;
  final bool hasRateOverride;
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
    required this.invoiceNo,
    required this.invoiceCategory,
    this.driverId,
    this.driverName,
    required this.subtotal,
    required this.gstAmount,
    required this.hasRateOverride,
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

  bool get isGst => invoiceCategory == InvoiceCategory.gst;

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        id: j['id'] as String,
        orderNo: j['order_no'] as String,
        invoiceNo: j['invoice_no'] as String? ?? '',
        invoiceCategory: j['invoice_category'] as String? ?? InvoiceCategory.general,
        driverId: j['driver_id'] as String?,
        driverName: j['driver_name'] as String?,
        subtotal: _d(j['subtotal']),
        gstAmount: _d(j['gst_amount']),
        hasRateOverride: j['has_rate_override'] as bool? ?? false,
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
        'invoice_no': invoiceNo,
        'invoice_category': invoiceCategory,
        'driver_id': driverId,
        'driver_name': driverName,
        'subtotal': subtotal,
        'gst_amount': gstAmount,
        'has_rate_override': hasRateOverride,
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
  final String? hsnCode;
  final int quantity;
  final double rate;
  final double? standardRate;
  final double amount;
  final bool isDefaultRate;
  final bool isRateOverride;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unit,
    this.hsnCode,
    required this.quantity,
    required this.rate,
    this.standardRate,
    required this.amount,
    required this.isDefaultRate,
    this.isRateOverride = false,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    final p = j['products'] as Map<String, dynamic>?;
    return OrderItem(
      productId: j['product_id'] as String,
      productName: p?['name'] as String? ?? '?',
      unit: p?['unit'] as String? ?? '',
      hsnCode: p?['hsn_code'] as String?,
      quantity: _i(j['quantity']),
      rate: _d(j['rate']),
      standardRate: j['standard_rate'] == null ? null : _d(j['standard_rate']),
      amount: _d(j['amount']),
      isDefaultRate: j['is_default_rate'] as bool? ?? false,
      isRateOverride: j['is_rate_override'] as bool? ?? false,
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
  final String invoiceNo;
  final String invoiceCategory;
  final String? partyAddress;
  final String? partyGstin;
  final String? driverId;
  final String? driverName;
  final String? vehicleNumber;
  final double gstRate;
  final double subtotal;
  final double cgstAmount;
  final double sgstAmount;
  final double roundOff;
  final bool hasRateOverride;
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
    required this.invoiceNo,
    required this.invoiceCategory,
    this.partyAddress,
    this.partyGstin,
    this.driverId,
    this.driverName,
    this.vehicleNumber,
    required this.gstRate,
    required this.subtotal,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.roundOff,
    required this.hasRateOverride,
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
    final party = j['parties'] as Map?;
    final driver = j['drivers'] as Map?;
    return OrderDetail(
      id: j['id'] as String,
      orderNo: j['order_no'] as String,
      invoiceNo: j['invoice_no'] as String? ?? '',
      invoiceCategory: j['invoice_category'] as String? ?? InvoiceCategory.general,
      partyAddress: party?['address'] as String?,
      partyGstin: party?['gstin'] as String?,
      driverId: j['driver_id'] as String?,
      driverName: driver?['name'] as String?,
      vehicleNumber: v?['vehicle_number'] as String?,
      gstRate: _d(j['gst_rate']),
      subtotal: _d(j['subtotal']),
      cgstAmount: _d(j['cgst_amount']),
      sgstAmount: _d(j['sgst_amount']),
      roundOff: _d(j['round_off']),
      hasRateOverride: j['has_rate_override'] as bool? ?? false,
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

  bool get isGst => invoiceCategory == InvoiceCategory.gst;
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
  final String? driverId; // 'none' = No driver
  final String? category;
  final bool? rateOverride;

  const OrderFilters({
    this.fromDate,
    this.toDate,
    this.partyId,
    this.productId,
    this.vehicleId,
    this.userId,
    this.status,
    this.search,
    this.driverId,
    this.category,
    this.rateOverride,
  });

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);

  Map<String, dynamic> toJson() => {
        if (fromDate != null) 'from_date': _date(fromDate!),
        if (toDate != null) 'to_date': _date(toDate!),
        if (partyId != null) 'party_ids': [partyId],
        if (productId != null) 'product_ids': [productId],
        if (vehicleId != null) 'vehicle_ids': [vehicleId],
        if (userId != null) 'user_ids': [userId],
        if (status != null) 'statuses': [status],
        if (driverId != null) 'driver_ids': [driverId],
        if (category != null) 'categories': [category],
        if (rateOverride != null) 'rate_override': rateOverride,
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
    Object? driverId = _keep,
    Object? category = _keep,
    Object? rateOverride = _keep,
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
        driverId: driverId == _keep ? this.driverId : driverId as String?,
        category: category == _keep ? this.category : category as String?,
        rateOverride: rateOverride == _keep ? this.rateOverride : rateOverride as bool?,
      );
}

const _keep = Object();
