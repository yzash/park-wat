import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Small on-device store: cached master data, the offline order queue, the
/// signed-in profile and form defaults. Scale is tiny (a few hundred parties,
/// tens of queued orders) so JSON in shared preferences is enough and works on
/// both Android and web.
class LocalStore {
  LocalStore(this._p);
  final SharedPreferences _p;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  Map<String, dynamic>? _readMap(String key) {
    final s = _p.getString(key);
    if (s == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMap(String key, Map<String, dynamic> v) => _p.setString(key, jsonEncode(v));

  // ---- profile ---------------------------------------------------------------
  AppUser? get profile {
    final m = _readMap('profile');
    return m == null ? null : AppUser.fromJson(m);
  }

  Future<void> setProfile(AppUser? u) => u == null ? _p.remove('profile') : _writeMap('profile', u.toJson());

  // ---- master data cache -------------------------------------------------------
  Map<String, dynamic>? get masters => _readMap('masters');
  Future<void> setMasters(Map<String, dynamic> m) => _writeMap('masters', m);

  // ---- offline queue (per user) ------------------------------------------------
  List<PendingOrder> queue(String uid) {
    final s = _p.getString('queue_$uid');
    if (s == null) return [];
    return (jsonDecode(s) as List).map((e) => PendingOrder.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> setQueue(String uid, List<PendingOrder> q) =>
      _p.setString('queue_$uid', jsonEncode(q.map((e) => e.toJson()).toList()));

  // ---- form defaults -------------------------------------------------------------
  String? lastPartyId(String uid) => _p.getString('last_party_$uid');
  String? lastVehicle(String uid) => _p.getString('last_vehicle_$uid'); // id or 'none'
  String? lastDriver(String uid) => _p.getString('last_driver_$uid'); // id or 'none'
  String? lastCategory(String uid) => _p.getString('last_category_$uid');

  Future<void> setLastUsed(String uid, {required String partyId, required String vehicle, required String driver, required String category}) async {
    await _p.setString('last_party_$uid', partyId);
    await _p.setString('last_vehicle_$uid', vehicle);
    await _p.setString('last_driver_$uid', driver);
    await _p.setString('last_category_$uid', category);
  }

  /// Last order's lines per party → one-tap "Repeat last order".
  List<OrderLineInput> lastItemsFor(String uid, String partyId) {
    final m = _readMap('last_items_$uid');
    final l = m?[partyId] as List?;
    return l == null ? [] : l.map((e) => OrderLineInput.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> setLastItems(String uid, String partyId, List<OrderLineInput> items) async {
    final m = _readMap('last_items_$uid') ?? {};
    m[partyId] = items.map((e) => e.toJson()).toList();
    await _writeMap('last_items_$uid', m);
  }

  // ---- last fetched "My Orders" list, shown when offline -------------------------
  List<OrderSummary> cachedMyOrders(String uid) {
    final s = _p.getString('my_orders_$uid');
    if (s == null) return [];
    return (jsonDecode(s) as List).map((e) => OrderSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> setCachedMyOrders(String uid, List<OrderSummary> l) =>
      _p.setString('my_orders_$uid', jsonEncode(l.map((e) => e.toJson()).toList()));
}
