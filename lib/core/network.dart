import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  static const Duration timeoutDuration = Duration(seconds: 15);

  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Map<String, dynamic>.from(data);
      }

      throw Exception(data['message'] ?? 'Terjadi kesalahan pada server (${response.statusCode}).');
    } on FormatException {
      throw Exception('Respon server tidak valid atau halaman tidak ditemukan (${response.statusCode}).');
    }
  }

  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'ngrok-skip-browser-warning': 'true',
              ...?headers,
            },
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Koneksi timeout. Pastikan server lokal dan ngrok sedang berjalan.');
    } on SocketException {
      throw Exception('Gagal terhubung ke server. Periksa koneksi internet atau server.');
    }
  }

  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Koneksi timeout. Pastikan server lokal dan ngrok sedang berjalan.');
    } on SocketException {
      throw Exception('Gagal terhubung ke server. Periksa koneksi internet atau server.');
    }
  }

  Future<Map<String, dynamic>> upload(
    String url, {
    required String filePath,
    required String fieldName,
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['ngrok-skip-browser-warning'] = 'true';

      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Upload timeout. Koneksi server terlalu lambat atau terputus.');
    } on SocketException {
      throw Exception('Gagal terhubung ke server saat upload.');
    }
  }

  Future<Map<String, dynamic>> uploadBytes(
    String url, {
    required Uint8List bytes,
    required String filename,
    required String fieldName,
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['ngrok-skip-browser-warning'] = 'true';

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
        ),
      );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('Upload timeout. Koneksi server terlalu lambat atau terputus.');
    } on SocketException {
      throw Exception('Gagal terhubung ke server saat upload.');
    }
  }
}
