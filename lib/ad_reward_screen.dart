import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'bamboo_economy.dart';

// REKLAM YÖNETİCİSİ (Global Servis)
// Bu sınıf reklamı arkada sürekli hazır tutar, sayfadan çıksan bile silinmez!
class RewardedAdManager {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoaded = false;
  static final String _adUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // Reklamı arkada yükleyen fonksiyon
  static void loadAd() {
    if (_isAdLoaded) return;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          debugPrint('✅ Ödüllü reklam arkada başarıyla hazırlandı!');
        },
        onAdFailedToLoad: (err) {
          _isAdLoaded = false;
          _rewardedAd = null;
          // Hata olursa 3 saniye sonra tekrar dene
          Future.delayed(const Duration(seconds: 3), loadAd);
        },
      ),
    );
  }

  // Reklam hazır mı?
  static bool get isReady => _isAdLoaded && _rewardedAd != null;

  // Reklamı göster
  static void showAd({
    required Function onRewarded,
    required Function onAdClosed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('⚠️ Reklam henüz hazır değil!');
      loadAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadAd(); // Kapatıldığı an arkadakini hemen yeniden yükle!
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadAd();
        onAdClosed();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onRewarded();
      },
    );
    
    _rewardedAd = null;
    _isAdLoaded = false;
  }
}

// =================ÜNİTE EKRANI=================
class AdRewardScreen extends StatefulWidget {
  const AdRewardScreen({super.key});

  @override
  State<AdRewardScreen> createState() => _AdRewardScreenState();
}

class _AdRewardScreenState extends State<AdRewardScreen> {
  bool _isGrantingReward = false;

  @override
  void initState() {
    super.initState();
    // Sayfa açılır açılmaz reklam hazır mı diye kontrol et, değilse tetikle
    if (!RewardedAdManager.isReady) {
      RewardedAdManager.loadAd();
    }
  }

  void _handleButtonPress() {
    // Eğer reklam o an hazır değilse bile kullanıcıya çaktırmadan hemen yükletmeye çalışıp uyarı verelim
    if (!RewardedAdManager.isReady) {
      RewardedAdManager.loadAd();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reklam yükleniyor, lütfen tekrar dokunun! ⏳'),
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 1000),
        ),
      );
      return;
    }

    // Reklam zaten hazır, direkt ANINDA patlat!
    RewardedAdManager.showAd(
      onRewarded: () async {
        setState(() => _isGrantingReward = true);
        
        await BambooEconomy.addCoins(2); 
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tebrikler! 2 Coin Kazandın 🪙'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() => _isGrantingReward = false);
        }
      },
      onAdClosed: () {
        setState(() {}); // Ekranı güncelle
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isReady = RewardedAdManager.isReady;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Coin Kazan'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: const Text('🪙', style: TextStyle(fontSize: 80)),
              ),
              const SizedBox(height: 32),
              const Text(
                'Ekstra Coin Kazan!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kısa bir reklam izleyerek hesabına hemen 2 Coin ekleyebilirsin. Bu coinleri Bambu ağacını büyütmek veya özel içerikleri açmak için kullanabilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: !_isGrantingReward ? _handleButtonPress : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  child: _isGrantingReward
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          // Kullanıcı tuşa bastığında reklam hazırsa direkt "Reklam İzle", 
                          // değilse bile tuş yine de aktif ve hızlıca açılmasını tetikler
                          isReady ? 'Reklam İzle (2 🪙)' : 'Reklam İzle (2 🪙)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}