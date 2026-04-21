class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String role; // admin | billing_staff | viewer
  final bool isActive;

  AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        username: j['username'] as String,
        fullName: j['full_name'] as String? ?? j['username'] as String,
        role: j['role'] as String,
        isActive: j['is_active'] as bool? ?? true,
      );
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final String role;
  final int userId;
  final String fullName;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.role,
    required this.userId,
    required this.fullName,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
        accessToken: j['access_token'] as String,
        tokenType: j['token_type'] as String? ?? 'bearer',
        role: j['role'] as String,
        userId: j['user_id'] as int,
        fullName: j['full_name'] as String? ?? '',
      );
}
