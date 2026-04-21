import '../../core/api/api_client.dart';
import '../models/user.dart';

class AuthRepo {
  final ApiClient _api;
  AuthRepo(this._api);

  Future<LoginResponse> login(String username, String password) async {
    final data = await _api.request('POST', '/auth/login', data: {
      'username': username,
      'password': password,
    });
    return LoginResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AppUser> me() async {
    final data = await _api.request('GET', '/auth/me');
    return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
