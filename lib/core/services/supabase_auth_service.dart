import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_service.dart';

class SupabaseAuthResponse {
  final Map<String, dynamic> user;
  final String? accessToken;
  final String? refreshToken;
  final bool alreadyExists;

  const SupabaseAuthResponse({
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.alreadyExists = false,
  });
}

class SupabaseAuthService {
  static const _projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _requestTimeout = Duration(seconds: 15);

  static bool get isConfigured =>
      _projectUrl.isNotEmpty && _publishableKey.isNotEmpty;
  static bool get isPartiallyConfigured =>
      _projectUrl.isNotEmpty != _publishableKey.isNotEmpty;

  static Future<SupabaseAuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/auth/v1/token', {'grant_type': 'password'}),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseAuthException(
        _errorMessage(body, 'Email atau kata sandi tidak valid.'),
        statusCode: response.statusCode,
      );
    }

    return SupabaseAuthResponse(
      user: body['user'] as Map<String, dynamic>,
      accessToken: body['access_token'] as String?,
      refreshToken: body['refresh_token'] as String?,
    );
  }

  static Future<SupabaseAuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await http
        .post(
          _uri('/auth/v1/signup'),
          headers: _headers,
          body: jsonEncode({
            'email': email,
            'password': password,
            'data': {'full_name': fullName},
          }),
        )
        .timeout(_requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseAuthException(
        _errorMessage(body, 'Pendaftaran akun online gagal.'),
        statusCode: response.statusCode,
      );
    }

    final user = body['user'] as Map<String, dynamic>? ?? body;
    return SupabaseAuthResponse(
      user: user,
      accessToken: body['access_token'] as String?,
      refreshToken: body['refresh_token'] as String?,
      alreadyExists:
          user['identities'] is List<dynamic> &&
          (user['identities'] as List<dynamic>).isEmpty,
    );
  }

  static Future<Map<String, dynamic>> getOrCreateProfile({
    required String userId,
    required String email,
    required String fullName,
    required String accessToken,
  }) async {
    final profileUri = _uri('/rest/v1/profiles', {
      'id': 'eq.$userId',
      'select': 'id,email,full_name,currency,created_at',
    });
    final headers = _headers..['Authorization'] = 'Bearer $accessToken';
    final response = await http
        .get(profileUri, headers: headers)
        .timeout(_requestTimeout);

    final result = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseAuthException(
        _errorMessage(
          result,
          'Gagal mengambil profil. Pastikan schema.sql dan RLS sudah diterapkan di Supabase.',
        ),
        statusCode: response.statusCode,
      );
    }

    final profiles = result['data'] as List<dynamic>;
    if (profiles.isNotEmpty) {
      return profiles.first as Map<String, dynamic>;
    }

    final createResponse = await http
        .post(
          _uri('/rest/v1/profiles'),
          headers: {
            ...headers,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'id': userId,
            'email': email,
            'full_name': fullName,
          }),
        )
        .timeout(_requestTimeout);

    final created = _decodeResponse(createResponse);
    if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
      throw SupabaseAuthException(
        _errorMessage(
          created,
          'Gagal membuat profil. Pastikan schema.sql dan RLS sudah diterapkan di Supabase.',
        ),
        statusCode: createResponse.statusCode,
      );
    }
    final createdProfiles = created['data'] as List<dynamic>;
    if (createdProfiles.isEmpty) {
      throw const SupabaseAuthException(
        'Supabase tidak mengembalikan profil setelah profil dibuat.',
      );
    }
    return createdProfiles.first as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getPublicFeedback({
    required String accountEmail,
  }) async {
    final response = await _authenticatedRequest(
      accountEmail: accountEmail,
      method: 'GET',
      uri: _uri('/rest/v1/public_feedback', {
        'select': 'id,comment,created_at',
        'order': 'created_at.desc',
      }),
    );
    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseAuthException(
        _errorMessage(
          body,
          'Gagal memuat kritik dan saran. Pastikan tabel public_feedback sudah dibuat di Supabase.',
        ),
        statusCode: response.statusCode,
      );
    }
    return (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Future<void> submitPublicFeedback({
    required String accountEmail,
    required String comment,
  }) async {
    final userId = await SessionService.getSupabaseUserId(accountEmail);
    if (userId == null || userId.isEmpty) {
      throw const SupabaseAuthException(
        'Akun online tidak ditemukan. Silakan masuk kembali.',
      );
    }
    final response = await _authenticatedRequest(
      accountEmail: accountEmail,
      method: 'POST',
      uri: _uri('/rest/v1/public_feedback'),
      body: jsonEncode({'user_id': userId, 'comment': comment}),
    );
    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseAuthException(
        _errorMessage(
          body,
          'Gagal mengirim kritik dan saran. Pastikan schema feedback sudah diterapkan.',
        ),
        statusCode: response.statusCode,
      );
    }
  }

  static Future<http.Response> _authenticatedRequest({
    required String accountEmail,
    required String method,
    required Uri uri,
    String? body,
  }) async {
    var accessToken = await SessionService.getSupabaseAccessToken(accountEmail);
    if (accessToken == null || accessToken.isEmpty) {
      accessToken = await _refreshAccessToken(accountEmail);
    }

    var response = await _sendAuthenticatedRequest(
      method: method,
      uri: uri,
      accessToken: accessToken,
      body: body,
    );
    if (response.statusCode == 401) {
      accessToken = await _refreshAccessToken(accountEmail);
      response = await _sendAuthenticatedRequest(
        method: method,
        uri: uri,
        accessToken: accessToken,
        body: body,
      );
    }
    return response;
  }

  static Future<http.Response> _sendAuthenticatedRequest({
    required String method,
    required Uri uri,
    required String accessToken,
    String? body,
  }) {
    final headers = {
      ..._headers,
      'Authorization': 'Bearer $accessToken',
      if (method == 'POST') 'Prefer': 'return=minimal',
    };
    return switch (method) {
      'GET' => http.get(uri, headers: headers).timeout(_requestTimeout),
      'POST' =>
        http.post(uri, headers: headers, body: body).timeout(_requestTimeout),
      _ => throw ArgumentError.value(
        method,
        'method',
        'Unsupported HTTP method',
      ),
    };
  }

  static Future<String> _refreshAccessToken(String accountEmail) async {
    final refreshToken = await SessionService.getSupabaseRefreshToken(
      accountEmail,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SupabaseAuthException(
        'Sesi online tidak tersedia. Silakan keluar lalu masuk kembali untuk mengakses kritik dan saran.',
      );
    }
    final response = await http
        .post(
          _uri('/auth/v1/token', {'grant_type': 'refresh_token'}),
          headers: _headers,
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_requestTimeout);
    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await SessionService.clearSupabaseTokens();
      throw SupabaseAuthException(
        _errorMessage(body, 'Sesi online berakhir. Silakan masuk kembali.'),
        statusCode: response.statusCode,
      );
    }
    final accessToken = body['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const SupabaseAuthException(
        'Supabase tidak memberikan token sesi yang baru.',
      );
    }
    await SessionService.saveSupabaseTokens(
      accountEmail: accountEmail,
      userId: (body['user'] as Map<String, dynamic>)['id'] as String,
      accessToken: accessToken,
      refreshToken: body['refresh_token'] as String? ?? refreshToken,
    );
    return accessToken;
  }

  static Map<String, String> get _headers => {
    'apikey': _publishableKey,
    'Content-Type': 'application/json',
  };

  static Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.tryParse(_projectUrl);
    if (base == null ||
        !base.hasScheme ||
        !base.hasAuthority ||
        (base.scheme != 'https' && !kDebugMode)) {
      throw const SupabaseAuthException(
        'SUPABASE_URL tidak valid. Gunakan URL HTTPS project Supabase.',
      );
    }
    return base.replace(
      path: '${base.path}$path',
      queryParameters: queryParameters,
    );
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) return {'data': <dynamic>[]};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List<dynamic>) return {'data': decoded};
    } on FormatException {
      throw const SupabaseAuthException('Respons Supabase tidak dapat dibaca.');
    }
    throw const SupabaseAuthException('Format respons Supabase tidak valid.');
  }

  static String _errorMessage(Map<String, dynamic> body, String fallback) =>
      (body['msg'] ??
              body['message'] ??
              body['error_description'] ??
              body['error'])
          ?.toString() ??
      fallback;
}

class SupabaseAuthException implements Exception {
  final String message;
  final int? statusCode;

  const SupabaseAuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
