import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token in the iOS Keychain; non-secret preferences in UserDefaults.
class TokenStore {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _tokenKey = 'github_pat';
  static const _projectKey = 'github_selected_project_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<String?> readSelectedProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_projectKey);
  }

  Future<void> writeSelectedProjectId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_projectKey);
    } else {
      await prefs.setString(_projectKey, id);
    }
  }
}
