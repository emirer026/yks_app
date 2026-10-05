import 'auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pomodoro_screen.dart'; 
import 'services/local_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_manager.dart';

void main() async {
  // 1. Flutter motorunun tam yüklendiğinden emin ol
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1.1 Google Mobile Ads SDK'yı başlat
  MobileAds.instance.initialize(); 

  // 1.2 Telefonunu test cihazı olarak kaydet (Geçersiz trafikten banlanmayı önler)
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      testDeviceIds: ['F953C836FB0CDD885902ED8A51B0E47B'],
    ),
  );
  
  // 1.3 Uygulama başlarken ilk geçiş reklamını arkada sessizce hazırla
  AdManager.loadInterstitialAd(); 

  // 2. Firebase'i projeye özel ayarlarla başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. İnternet kopmalarına ve limitlere karşı yerel önbellek korumasını aktif et
  await LocalManager.initOfflinePersistence();

  runApp(const YksApp());
}

class YksApp extends StatelessWidget {
  const YksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Global navigatorKey buraya entegre edildi
      navigatorKey: PomodoroManager.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'YKS Asistanı',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: const SplashScreen(),
    );
  }
}

// AÇILIŞ (SPLASH) EKRANI
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return; // Güvenlik kontrolü eklendi
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover, 
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 120.0),
              child: FractionallySizedBox(
                widthFactor: 0.75,
                child: Image.asset('assets/logo.png'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}