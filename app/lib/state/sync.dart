import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/api.dart';
import '../data/local_store.dart';
import '../data/models.dart';

/// Offline order queue (FR-12). Every new order is written here first, then
/// pushed to the server. Retries on reconnect, on app resume and every minute.
/// The server call is idempotent (client-generated id), so retries never duplicate.
class SyncState extends ChangeNotifier {
  SyncState(this._api, this._store);
  final Api _api;
  final LocalStore _store;

  String? _uid;
  List<PendingOrder> pending = [];
  bool syncing = false;
  bool online = true;
  StreamSubscription<List<ConnectivityResult>>? _conn;
  Timer? _timer;

  /// Fires with (localId, orderNo) whenever a queued order reaches the server.
  final _synced = StreamController<({String id, String orderNo})>.broadcast();
  Stream<({String id, String orderNo})> get synced => _synced.stream;

  int get pendingCount => pending.length;

  void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    pending = _store.queue(uid);
    _conn = Connectivity().onConnectivityChanged.listen((r) {
      final now = r.any((c) => c != ConnectivityResult.none);
      if (now != online) {
        online = now;
        notifyListeners();
      }
      if (now) syncNow();
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => syncNow());
    notifyListeners();
    syncNow();
  }

  void stop() {
    _conn?.cancel();
    _timer?.cancel();
    _conn = null;
    _timer = null;
    _uid = null;
    pending = [];
  }

  Future<void> _save() async {
    if (_uid != null) await _store.setQueue(_uid!, pending);
    notifyListeners();
  }

  /// Queues the order and tries to send it right away.
  /// Returns the order number if it reached the server, null if it stays queued.
  Future<String?> submit(PendingOrder o) async {
    pending = [...pending, o];
    await _save();
    await syncNow();
    if (pending.any((p) => p.id == o.id)) {
      final p = pending.firstWhere((p) => p.id == o.id);
      if (p.lastError != null) throw ApiException(p.lastError!);
      return null;
    }
    return _lastOrderNos[o.id];
  }

  final Map<String, String> _lastOrderNos = {};

  Future<void> syncNow() async {
    if (syncing || _uid == null || pending.isEmpty) return;
    syncing = true;
    notifyListeners();
    try {
      for (final o in List.of(pending)) {
        if (o.lastError != null) continue; // needs user attention
        try {
          final res = await _api.submitOrder(o);
          final no = res['order_no'] as String;
          _lastOrderNos[o.id] = no;
          pending = pending.where((p) => p.id != o.id).toList();
          await _save();
          _synced.add((id: o.id, orderNo: no));
          if (!online) {
            online = true;
          }
        } catch (e) {
          if (isNetworkError(e)) {
            online = false;
            break; // still offline; keep the rest queued
          }
          pending = [for (final p in pending) p.id == o.id ? p.withError(errorMessage(e)) : p];
          await _save();
        }
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> retry(String id) async {
    pending = [for (final p in pending) p.id == id ? p.withError(null) : p];
    await _save();
    await syncNow();
  }

  Future<void> discard(String id) async {
    pending = pending.where((p) => p.id != id).toList();
    await _save();
  }

  @override
  void dispose() {
    stop();
    _synced.close();
    super.dispose();
  }
}
