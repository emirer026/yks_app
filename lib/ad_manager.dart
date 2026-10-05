import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static DateTime? _lastAdShowTime;
  
  // Uygulamanın açıldığı anı kaydediyoruz (İlk 3 dakika koruması için)
  static final DateTime _appStartTime = DateTime.now();
  
  // Süreler
  static const int _appStartGraceMinutes = 3; // İlk açılışta reklamsız geçecek süre
  static const int _adCooldownMinutes = 15;     // Reklamlar arası normal bekleme süresi

  // Gerçek Geçiş Reklamı (Interstitial) ID'si
  static final String _adUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // Reklamı arka planda sessizce yükler
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
        },
      ),
    );
  }

  // Sayfa geçişlerinde çağrılacak asıl fonksiyon
  static void showInterstitialAd(VoidCallback onComplete) {
    final now = DateTime.now();

    // 0. KONTROL: Uygulama açılalı henüz 3 dakika geçmediyse reklam gösterme!
    if (now.difference(_appStartTime).inMinutes < _appStartGraceMinutes) {
      onComplete();
      return;
    }

    // 1. Durum: Reklam henüz yüklenmediyse direkt sayfaya geç ve arkada yenisini yüklemeye çalış
    if (_interstitialAd == null) {
      onComplete();
      loadInterstitialAd();
      return;
    }

    // 2. Durum: 15 dakika dolmadıysa reklamsız direkt sayfaya geç
    if (_lastAdShowTime != null) {
      final difference = now.difference(_lastAdShowTime!);
      if (difference.inMinutes < _adCooldownMinutes) {
        onComplete();
        return;
      }
    }

    // 3. Durum: Her şey hazır, ilk 3 dakika geçti ve 15 dakikalık cooldown doldu! Reklamı göster.
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        // Kullanıcı reklamı kapattığında:
        ad.dispose();
        _interstitialAd = null;
        _lastAdShowTime = DateTime.now(); // 15 dakikalık sayacı SIFIRLA
        loadInterstitialAd(); // Bir sonraki geçiş için arkada yenisini yükle
        onComplete(); // Diğer sayfaya geçişi tamamla
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        // Reklam gösterilirken hata olursa kullanıcıyı takılı bırakma, sayfaya geçir
        ad.dispose();
        _interstitialAd = null;
        onComplete();
        loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
  }
}