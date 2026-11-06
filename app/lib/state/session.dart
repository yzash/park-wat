import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/api.dart';
import '../data/local_store.dart';
import '../data/models.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Who is signed in. The session persists until logout (FR-01); when offline
/// the cached profile is used so order takers can keep capturing orders.
class SessionState extends ChangeNotifier {
  SessionState(this._api, this._store);
  final Api _api;
  final LocalStore _store;
  StreamSubscription<AuthState>? _sub;

  SessionStatus status = SessionStatus.loading;
  AppUser? user;

  bool get isAdmin => user?.isAdmin ?? false;

  Future<void> init() async {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut && status == SessionStatus.signedIn) {
        _setSignedOut();
      }
    });
    if (!_api.hasSession) {
      _setSignedOut();
      return;
    }
    final cached = _store.profile;
    if (cached != null && cached.id == _api.currentUid) {
      user = cached;
      status = SessionStatus.signedIn;
      notifyListeners();
    }
    await refreshProfile();
  }

  /// Re-reads the profile; signs out if the account was deactivated.
  Future<void> refreshProfile() async {
    try {
      final p = await _api.fetchProfile().timeout(const Duration(seconds: 10));
      if (p == null || !p.isActive) {
        await signOut();
        return;
      }
      user = p;
      status = SessionStatus.signedIn;
      await _store.setProfile(p);
      notifyListeners();
    } catch (e) {
      if (status == SessionStatus.loading) {
        // Offline with a stored session but no cached profile: we can't tell the role.
        if (_store.profile == null) _setSignedOut();
      }
    }
  }

  Future<void> signIn(String userId, String password) async {
    await _api.signIn(userId, password);
    final p = await _api.fetchProfile();
    if (p == null || !p.isActive) {
      await _api.signOut();
      throw ApiException('This account is not active. Contact the admin.');
    }
    user = p;
    await _store.setProfile(p);
    status = SessionStatus.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _api.signOut();
    } catch (_) {}
    _setSignedOut();
  }

  void _setSignedOut() {
    user = null;
    status = SessionStatus.signedOut;
    _store.setProfile(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
