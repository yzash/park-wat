import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'models.dart';

/// Thrown for problems the user should read (validation, permissions, …).
class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// True when the failure means "no network / server unreachable" rather than
/// "the server said no". Offline-queued orders are only retried in this case.
bool isNetworkError(Object e) {
  if (e is ApiException || e is PostgrestException) return false;
  if (e is AuthException) {
    return e.statusCode == null || e.message.toLowerCase().contains('socket') || e.message.toLowerCase().contains('failed host');
  }
  if (e is FunctionException) return false;
  // SocketException, ClientException, TimeoutException, HandshakeException…
  return true;
}

/// Human-readable message for any backend error.
String errorMessage(Object e) {
  if (e is ApiException) return e.message;
  if (e is PostgrestException) {
    if (e.code == '23505') return 'That already exists (duplicate name or number)';
    if (e.code == '42501') return e.message.contains('row-level security') ? 'You do not have permission to do that' : e.message;
    return e.message;
  }
  if (e is AuthException) {
    if (e.message.toLowerCase().contains('invalid login')) return 'Wrong user ID or password';
    if (e.message.toLowerCase().contains('banned')) return 'This account has been deactivated';
    return e.message;
  }
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return e.reasonPhrase ?? 'Server error (${e.status})';
  }
  if (e is TimeoutException) return 'The server took too long to respond';
  return 'No connection to the server';
}

class Api {
  SupabaseClient get _c => Supabase.instance.client;
  String? get currentUid => _c.auth.currentUser?.id;
  bool get hasSession => _c.auth.currentSession != null;

  static String loginEmail(String userId) => '${userId.trim().toLowerCase()}@${AppConfig.loginDomain}';

  // ---- auth --------------------------------------------------------------------
  Future<void> signIn(String userId, String password) =>
      _c.auth.signInWithPassword(email: loginEmail(userId), password: password);

  Future<void> signOut() => _c.auth.signOut();

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final me = await fetchProfile();
    if (me == null) throw ApiException('Not signed in');
    // Re-check the current password before changing it.
    await _c.auth.signInWithPassword(email: loginEmail(me.userId), password: currentPassword);
    await _c.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<AppUser?> fetchProfile() async {
    final uid = currentUid;
    if (uid == null) return null;
    final row = await _c.from('users').select().eq('id', uid).maybeSingle();
    return row == null ? null : AppUser.fromJson(row);
  }

  // ---- master data ---------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _all(String table, {String select = '*', String? order}) async {
    const page = 1000;
    final out = <Map<String, dynamic>>[];
    for (var from = 0;; from += page) {
      var q = _c.from(table).select(select);
      final rows = await (order != null ? q.order(order, ascending: true) : q).range(from, from + page - 1);
      out.addAll(rows);
      if (rows.length < page) break;
    }
    return out;
  }

  /// Everything the order form needs, as one JSON blob for the local cache.
  Future<Map<String, dynamic>> fetchMasters() async {
    final r = await Future.wait([
      _all('products', order: 'name'),
      _all('vehicles', order: 'vehicle_number'),
      _all('parties', order: 'name'),
      _all('current_party_rates', select: 'party_id,product_id,rate,effective_from'),
    ]);
    return {
      'products': r[0],
      'vehicles': r[1],
      'parties': r[2],
      'rates': r[3],
      'fetched_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<List<Product>> products() async => (await _all('products', order: 'name')).map(Product.fromJson).toList();
  Future<List<Vehicle>> vehicles() async =>
      (await _all('vehicles', order: 'vehicle_number')).map(Vehicle.fromJson).toList();
  Future<List<Party>> parties() async => (await _all('parties', order: 'name')).map(Party.fromJson).toList();

  Future<void> saveProduct({String? id, required String name, required String unit, required double defaultRate, required bool isActive}) async {
    final row = {'name': name.trim(), 'unit': unit.trim(), 'default_rate': defaultRate, 'is_active': isActive};
    id == null ? await _c.from('products').insert(row) : await _c.from('products').update(row).eq('id', id);
  }

  Future<void> saveVehicle({String? id, required String number, String? label, required bool isActive}) async {
    final row = {
      'vehicle_number': number.trim().toUpperCase(),
      'label': (label ?? '').trim().isEmpty ? null : label!.trim(),
      'is_active': isActive,
    };
    id == null ? await _c.from('vehicles').insert(row) : await _c.from('vehicles').update(row).eq('id', id);
  }

  Future<Party> saveParty({String? id, required String name, String? contactName, String? phone, String? address, required bool isActive}) async {
    String? n(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    final row = {'name': name.trim(), 'contact_name': n(contactName), 'phone': n(phone), 'address': n(address), 'is_active': isActive};
    final saved = id == null
        ? await _c.from('parties').insert(row).select().single()
        : await _c.from('parties').update(row).eq('id', id).select().single();
    return Party.fromJson(saved);
  }

  Future<List<PartyRate>> partyRates(String partyId) async {
    final rows = await _c
        .from('party_rates')
        .select()
        .eq('party_id', partyId)
        .order('effective_from', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(PartyRate.fromJson).toList();
  }

  Future<void> saveRate(PartyRate r) => _c.from('party_rates').upsert(r.toJson(), onConflict: 'party_id,product_id,effective_from');

  Future<Map<String, dynamic>> importMasters(List<Map<String, dynamic>> parties, List<Map<String, dynamic>> rates) async {
    final res = await _c.rpc('import_masters', params: {'p_parties': parties, 'p_rates': rates});
    return Map<String, dynamic>.from(res as Map);
  }

  // ---- users (admin) -------------------------------------------------------------
  Future<List<AppUser>> users() async => (await _all('users', order: 'full_name')).map(AppUser.fromJson).toList();
  Future<List<RoleInfo>> roles() async => (await _c.from('roles').select()).map(RoleInfo.fromJson).toList();

  Future<Map<String, dynamic>> _adminUsers(Map<String, dynamic> body) async {
    final res = await _c.functions.invoke('admin-users', body: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> createUser({required String userId, required String fullName, required String role, required String password}) =>
      _adminUsers({'action': 'create', 'user_id': userId, 'full_name': fullName, 'role': role, 'password': password});

  Future<void> updateUser(String id, {required String fullName, required String role}) =>
      _adminUsers({'action': 'update', 'id': id, 'full_name': fullName, 'role': role});

  Future<void> resetPassword(String id, String password) =>
      _adminUsers({'action': 'reset_password', 'id': id, 'password': password});

  Future<void> setUserActive(String id, bool active) =>
      _adminUsers({'action': 'set_active', 'id': id, 'is_active': active});

  // ---- orders ------------------------------------------------------------------------
  Future<Map<String, dynamic>> submitOrder(PendingOrder o) async {
    final res = await _c.rpc('submit_order', params: {
      'p_id': o.id,
      'p_party_id': o.partyId,
      'p_vehicle_id': o.vehicleId,
      'p_notes': o.notes,
      'p_items': o.items.map((e) => e.toJson()).toList(),
      'p_order_datetime': o.orderDatetime.toIso8601String(),
    }).timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateOrder(String id, {required String partyId, String? vehicleId, String? notes, required List<OrderLineInput> items}) async {
    final res = await _c.rpc('update_order', params: {
      'p_id': id,
      'p_party_id': partyId,
      'p_vehicle_id': vehicleId,
      'p_notes': notes,
      'p_items': items.map((e) => e.toJson()).toList(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> setOrderStatus(String id, String status) =>
      _c.rpc('set_order_status', params: {'p_id': id, 'p_status': status});

  Future<List<OrderSummary>> searchOrders(OrderFilters f, {int limit = 100, int offset = 0}) async {
    final rows = await _c.rpc('search_orders', params: {'p_filters': f.toJson(), 'p_limit': limit, 'p_offset': offset});
    return (rows as List).map((e) => OrderSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<TotalRow>> orderTotals(String groupBy, OrderFilters f) async {
    final rows = await _c.rpc('order_totals', params: {'p_group_by': groupBy, 'p_filters': f.toJson()});
    return (rows as List).map((e) => TotalRow.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<OrderDetail> getOrder(String id) async {
    final row = await _c
        .from('orders')
        .select('*, parties(name), vehicles(vehicle_number,label), '
            'creator:users!orders_created_by_fkey(full_name), updater:users!orders_updated_by_fkey(full_name), '
            'order_items(product_id, quantity, rate, amount, is_default_rate, products(name, unit)), '
            'order_status_log(from_status, to_status, changed_at, changer:users!order_status_log_changed_by_fkey(full_name))')
        .eq('id', id)
        .single();
    return OrderDetail.fromJson(row);
  }

  /// Calls the export-orders edge function and returns the .xlsx bytes.
  Future<({Uint8List bytes, String filename})> exportOrders(OrderFilters f) async {
    final session = _c.auth.currentSession;
    if (session == null) throw ApiException('Not signed in');
    final res = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}/functions/v1/export-orders'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConfig.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'filters': f.toJson()}),
    );
    if (res.statusCode != 200) {
      String msg = 'Export failed (${res.statusCode})';
      try {
        msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
      } catch (_) {}
      throw ApiException(msg);
    }
    final cd = res.headers['content-disposition'] ?? '';
    final m = RegExp(r'filename="([^"]+)"').firstMatch(cd);
    return (bytes: res.bodyBytes, filename: m?.group(1) ?? 'PWP-orders.xlsx');
  }
}
