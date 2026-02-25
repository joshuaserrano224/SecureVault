import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Save JWT/Auth Token
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // Get Token
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Delete Token
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}

//By Marl Laurence Soriano, Security