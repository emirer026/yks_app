import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

class UserDataService {
  static final _firestore = FirebaseFirestore.instance;
  static Map<String, dynamic>? _cachedData;
  static bool _isFetching = false;
  static String? _lastLoadedUid; // Hangi kullanıcının verisinin cache'lendiğini takip eder

  // Firebase Auth'un oturumu restore etmesi için güvenli kullanıcı alıcı (Açılış yarışını önler)
  static Future<User?> _getVerifiedUser() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser;
    
    try {
      return await auth.authStateChanges().timeout(
        const Duration(milliseconds: 600),
        onTimeout: (sink) => sink.close(),
      ).first;
    } catch (_) {
      return auth.currentUser;
    }
  }

  static Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final user = await _getVerifiedUser();
    // Her kullanıcının UID'sine özel dosya adı oluşturulur. Giriş yapılmadıysa guest dosyası kullanılır.
    final uid = user != null ? user.uid : 'guest';
    return File('${directory.path}/bamboo_local_data_$uid.json');
  }

  // Kullanıcı değiştiğinde veya çıkış yaptığında cache'i sıfırlamak için
  static Future<void> clearCacheIfUserChanged() async {
    final user = await _getVerifiedUser();
    final currentUid = user != null ? user.uid : 'guest';
    if (_lastLoadedUid != currentUid) {
      _cachedData = null;
      _lastLoadedUid = currentUid;
    }
  }

  // Sosyal, Kullanıcı adı ve Ekonomi/Bambu verilerini buluta (Firebase'e) bağlayan akıllı filtre
  static bool _isCloudModule(String moduleKey) {
    final key = moduleKey.toLowerCase();
    return key.contains('message') || 
           key.contains('friend') || 
           key.contains('chat') || 
           key.contains('block') || 
           key.contains('request') ||
           key.contains('bamboo') || 
           key.contains('coin') || 
           key.contains('water') || 
           key.contains('seed') ||
           key.contains('name') ||    // Bulut senkronizasyonu
           key.contains('user') ||    // Bulut senkronizasyonu
           key.contains('profile');   // Bulut senkronizasyonu
  }

  static Future<Map<String, dynamic>> fetchAllData({bool forceRefresh = false}) async {
    await clearCacheIfUserChanged();

    if (_cachedData != null && !forceRefresh) {
      return _cachedData!;
    }

    while (_isFetching) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_cachedData != null) return _cachedData!;
    }

    _isFetching = true;
    try {
      // 1. Oturum açan kullanıcıya özel yerel kişisel verileri oku
      final file = await _getLocalFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          _cachedData = Map<String, dynamic>.from(jsonDecode(contents));
        } else {
          _cachedData = {};
        }
      } else {
        _cachedData = {};
      }

      // 2. Bulut verilerini doğrudan Firebase'den çekip ekle
      final user = await _getVerifiedUser();
      if (user != null) {
        final doc = await _firestore.collection('users_data').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final remoteData = doc.data()!;
          remoteData.forEach((key, value) {
            if (_isCloudModule(key)) {
              _cachedData![key] = value;
            }
          });
        }
      }
    } catch (e) {
      print("⚠️ HATA: Veriler okunamadı: $e");
      _cachedData ??= {};
    } finally {
      _isFetching = false;
    }

    return _cachedData!;
  }

  static Future<void> saveModuleData(String moduleKey, dynamic data) async {
    await clearCacheIfUserChanged();
    _cachedData ??= {};

    // Eğer veri mesajlaşma veya sohbet içeriyorsa 500 sınırını uygula
    if ((moduleKey.contains('message') || moduleKey.contains('chat')) && data is List) {
      if (data.length > 500) {
        data = data.sublist(data.length - 500);
        print("🧹 Mesaj limiti aşıldı: En eski mesajlar temizlendi, güncel 500 mesaj tutuluyor.");
      }
    }

    _cachedData![moduleKey] = data;

    // EĞER BULUT MODÜLÜSE -> Firebase'e kaydet
    if (_isCloudModule(moduleKey)) {
      final user = await _getVerifiedUser();
      if (user != null) {
        print("☁️ Bulut verileri Firebase'e kaydediliyor: $moduleKey");
        await _firestore.collection('users_data').doc(user.uid).set({
          moduleKey: data,
        }, SetOptions(merge: true));
      }
      return;
    }

    // EĞER KİŞİSEL MODÜLSE -> Sadece o kullanıcının UID'sine ait yerel dosyaya kaydet
    print("📁 Kişisel veriler yerel diske kaydediliyor: $moduleKey");
    try {
      final fileReal = await _getLocalFile();
      
      final Map<String, dynamic> localDataOnly = {};
      _cachedData!.forEach((key, value) {
        if (!_isCloudModule(key)) {
          localDataOnly[key] = value;
        }
      });

      await fileReal.writeAsString(jsonEncode(localDataOnly));
    } catch (e) {
      print("⚠️ HATA: Yerel veriler kaydedilemedi: $e");
    }
  }
}