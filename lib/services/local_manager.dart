import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalManager {
  static final LocalManager instance = LocalManager._init();
  LocalManager._init();

  static const String _keyLocalCoins = 'pending_bamboo_coins';
  static const String _keyLocalFocusMins = 'pending_bamboo_focus_mins';

  // 1. Firebase Çevrimdışı Önbelleğini Aktif Etme
  static Future<void> initOfflinePersistence() async {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
  }

  // 2. Çalışma Sırasında Veriyi Sadece Telefonda Biriktir (0 Yazma Maliyeti)
  Future<void> addLocalFocusAndCoins(int extraMinutes, int extraCoins) async {
    final prefs = await SharedPreferences.getInstance();
    int currentCoins = prefs.getInt(_keyLocalCoins) ?? 0;
    int currentFocus = prefs.getInt(_keyLocalFocusMins) ?? 0;

    await prefs.setInt(_keyLocalCoins, currentCoins + extraCoins);
    await prefs.setInt(_keyLocalFocusMins, currentFocus + extraMinutes);
    
    print("📱 Veri telefonda güvenle saklandı -> Süre: ${currentFocus + extraMinutes} dk, Coin: ${currentCoins + extraCoins}");
  }

  // 3. Uygulama Açıldığında veya Uygun Anda Telefonda Birikenleri Firestore'a Aktar
  Future<void> syncPendingDataToFirestore() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    int pendingCoins = prefs.getInt(_keyLocalCoins) ?? 0;
    int pendingFocus = prefs.getInt(_keyLocalFocusMins) ?? 0;

    // Gönderilecek bir veri yoksa boşuna istek atma
    if (pendingCoins == 0 && pendingFocus == 0) return;

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users_data').doc(currentUser.uid);

      // Firestore'a atomic (artırımlı) olarak gönderiyoruz (Limitleri patlatmayan tekil yazma)
      await userDocRef.set({
        'bamboo_coins': FieldValue.increment(pendingCoins),
        'bamboo_focus_minutes': FieldValue.increment(pendingFocus),
      }, SetOptions(merge: true));

      // Başarıyla gönderildiği için telefondaki bekleyen (pending) sayaçları sıfırla
      await prefs.setInt(_keyLocalCoins, 0);
      await prefs.setInt(_keyLocalFocusMins, 0);
      
      print("☁️ Telefonda biriken veriler başarıyla Firebase'e senkronize edildi!");
    } catch (e) {
      print("⚠️ Firebase limit dolu veya internet yok, veriler telefonda güvende kalmaya devam ediyor: $e");
    }
  }

  // Toplam Gösterilecek Coin (Firebase + Telefonda henüz gönderilememiş olanlar)
  Future<int> getTotalCoins() async {
    final prefs = await SharedPreferences.getInstance();
    int pendingCoins = prefs.getInt(_keyLocalCoins) ?? 0;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance.collection('users_data').doc(currentUser.uid).get();
        int serverCoins = (doc.data()?['bamboo_coins'] ?? 0) as int;
        return serverCoins + pendingCoins;
      }
    } catch (_) {}
    
    return pendingCoins;
  }
}