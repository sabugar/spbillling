import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _kToken = 'access_token';
  static const _kRole = 'role';
  static const _kUserId = 'user_id';
  static const _kFullName = 'full_name';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  Future<void> saveSession({
    required String token,
    required String role,
    required int userId,
    required String fullName,
  }) async {
    final p = await _p;
    await p.setString(_kToken, token);
    await p.setString(_kRole, role);
    await p.setInt(_kUserId, userId);
    await p.setString(_kFullName, fullName);
  }

  Future<String?> readToken() async => (await _p).getString(_kToken);
  Future<String?> readRole() async => (await _p).getString(_kRole);
  Future<String?> readFullName() async => (await _p).getString(_kFullName);

  Future<void> clear() async {
    final p = await _p;
    await p.remove(_kToken);
    await p.remove(_kRole);
    await p.remove(_kUserId);
    await p.remove(_kFullName);
  }
}
