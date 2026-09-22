import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../model/app_control.dart';

class AppControlRemoteDataSource {
  AppControlRemoteDataSource(this._client);

  final http.Client _client;

  Future<AppControl> read() async {
    final Uri uri =
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/app_control').replace(
      queryParameters: <String, String>{
        'id': 'eq.main',
        'select': 'is_blocked,message_ar,message_en,updated_at',
        'limit': '1',
      },
    );
    final http.Response response =
        await _client.get(uri, headers: <String, String>{
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
          'App control request failed: ${response.statusCode}', uri);
    }
    final List<dynamic> rows = jsonDecode(response.body) as List<dynamic>;
    return rows.isEmpty
        ? AppControl.open
        : AppControl.fromJson(rows.first as Map<String, dynamic>);
  }
}
