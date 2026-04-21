import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../auth/auth_storage.dart';

/// Thrown for any non-2xx response. Carries the backend `detail` message.
class ApiError implements Exception {
  final int? status;
  final String message;
  ApiError(this.status, this.message);
  @override
  String toString() => 'ApiError($status): $message';
}

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient(AuthStorage storage) {
    final baseUrl = _defaultBaseUrl();
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (_) => true,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
    return ApiClient._(dio);
  }

  static String _defaultBaseUrl() {
    // Android emulator remaps host loopback to 10.0.2.2
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8001/api';
    return 'http://localhost:8001/api';
  }

  /// Returns the `data` field on success, throws ApiError otherwise.
  Future<dynamic> request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    ResponseType? responseType,
  }) async {
    final resp = await _dio.request<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: Options(method: method, responseType: responseType),
    );
    final status = resp.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      final body = resp.data;
      String msg = 'Request failed ($status)';
      if (body is Map && body['detail'] is String) msg = body['detail'] as String;
      throw ApiError(status, msg);
    }
    if (responseType == ResponseType.bytes) return resp.data;
    final body = resp.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  /// Like [request] but returns the full envelope (for paginated responses).
  Future<Map<String, dynamic>> requestEnvelope(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final resp = await _dio.request<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: Options(method: method),
    );
    final status = resp.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      final body = resp.data;
      String msg = 'Request failed ($status)';
      if (body is Map && body['detail'] is String) msg = body['detail'] as String;
      throw ApiError(status, msg);
    }
    return Map<String, dynamic>.from(resp.data as Map);
  }
}
