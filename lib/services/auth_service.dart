import 'package:shared_preferences/shared_preferences.dart';
import 'azure_storage_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  
  factory AuthService() {
    return instance;
  }

  AuthService._internal();

  static const String _sasUrlKey = 'sas_url';
  static const String _containerNameKey = 'container_name';

  AzureStorageService? _storageService;
  AzureStorageService get storageService {
    if (_storageService == null) {
      throw Exception('Not logged in');
    }
    return _storageService!;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final sasUrl = prefs.getString(_sasUrlKey);
    final containerName = prefs.getString(_containerNameKey);
    return sasUrl != null && containerName != null;
  }

  Future<void> login({
    required String sasUrl,
    required String containerName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sasUrlKey, sasUrl);
    await prefs.setString(_containerNameKey, containerName);

    _storageService = AzureStorageService(
      sasUrl: sasUrl,
      containerName: containerName,
    );
  }

  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sasUrl = prefs.getString(_sasUrlKey);
    final containerName = prefs.getString(_containerNameKey);

    if (sasUrl != null && containerName != null) {
      _storageService = AzureStorageService(
        sasUrl: sasUrl,
        containerName: containerName,
      );
      return true;
    }

    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sasUrlKey);
    await prefs.remove(_containerNameKey);
    _storageService = null;
  }
} 