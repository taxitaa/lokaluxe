import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SupabaseAuthResponse {
  final Map<String, dynamic> user;
  final String? accessToken;
  final bool alreadyExists;

  const SupabaseAuthResponse({
    required this.user,
    this.accessToken,
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
    final headers = _headers
      ..['Authorization'] = 'Bearer ' + accessToken;
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
      throw const SupabaseAuthException(
        'Respons Supabase tidak dapat dibaca.',
      );
    }
    throw const SupabaseAuthException('Format respons Supabase tidak valid.');
  }

  static String _errorMessage(
    Map<String, dynamic> body,
    String fallback,
  ) =>
      (body['msg'] ?? body['message'] ?? body['error_description'] ?? body['error'])
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
