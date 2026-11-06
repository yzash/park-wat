import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../data/local_store.dart';
import '../data/models.dart';

/// Products, vehicles, parties and current party rates. Loaded from the local
/// cache instantly (the form opens offline in well under a second), refreshed
/// from the server in the background.
class MastersState extends ChangeNotifier {
  MastersState(this._api, this._store) {
    _apply(_store.masters);
  }
  final Api _api;
  final LocalStore _store;

  List<Product> products = [];
  List<Vehicle> vehicles = [];
  List<Party> parties = [];
  List<Driver> drivers = [];
  AppSettings settings = AppSettings.fallback;
  final Map<String, double> _rates = {}; // "$partyId|$productId" → rate
  DateTime? fetchedAt;
  bool loading = false;
  String? error;

  bool get isEmpty => parties.isEmpty && products.isEmpty;

  List<Party> get activeParties => parties.where((p) => p.isActive).toList();
  List<Product> get activeProducts => products.where((p) => p.isActive).toList();
  List<Vehicle> get activeVehicles => vehicles.where((v) => v.isActive).toList();
  List<Driver> get activeDrivers => drivers.where((d) => d.isActive).toList();
  Driver? driver(String? id) => id == null ? null : drivers.where((d) => d.id == id).firstOrNull;

  Party? party(String? id) => id == null ? null : parties.where((p) => p.id == id).firstOrNull;
  Product? product(String? id) => id == null ? null : products.where((p) => p.id == id).firstOrNull;
  Vehicle? vehicle(String? id) => id == null ? null : vehicles.where((v) => v.id == id).firstOrNull;

  /// Rate the server will apply: the party's rate list, else the product default.
  ({double rate, bool isDefault}) rateFor(String partyId, String productId) {
    final r = _rates['$partyId|$productId'];
    if (r != null) return (rate: r, isDefault: false);
    return (rate: product(productId)?.defaultRate ?? 0, isDefault: true);
  }

  void _apply(Map<String, dynamic>? m) {
    if (m == null) return;
    List<Map<String, dynamic>> l(String k) =>
        ((m[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    products = l('products').map(Product.fromJson).toList();
    vehicles = l('vehicles').map(Vehicle.fromJson).toList();
    parties = l('parties').map(Party.fromJson).toList();
    drivers = l('drivers').map(Driver.fromJson).toList();
    final st = m['settings'];
    if (st is Map) settings = AppSettings.fromJson(Map<String, dynamic>.from(st));
    _rates.clear();
    for (final r in l('rates')) {
      final rate = r['rate'];
      _rates['${r['party_id']}|${r['product_id']}'] = rate is num ? rate.toDouble() : double.parse('$rate');
    }
    fetchedAt = m['fetched_at'] == null ? null : DateTime.parse(m['fetched_at'] as String);
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final m = await _api.fetchMasters().timeout(const Duration(seconds: 30));
      await _store.setMasters(m);
      _apply(m);
    } catch (e) {
      error = errorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
