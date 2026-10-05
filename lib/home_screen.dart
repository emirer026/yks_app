import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';
import 'pomodoro_screen.dart';
import 'corkboard_screen.dart';
import 'ezber_screen.dart';
import 'bilgi_karti_screen.dart';
import 'grafik_screen.dart';
import 'konu_takip_screen.dart';
import 'haftalik_program_screen.dart';
import 'soru_biriktirici_screen.dart';
import 'pdf_library_screen.dart';
import 'deneme_analiz_screen.dart';
import 'bamboo_screen.dart';
import 'bamboo_economy.dart';
import 'ad_reward_screen.dart';
import 'leaderboard_screen.dart';
import 'banner_ad_widget.dart';
import 'profile_cache.dart';
import 'dart:io';
import 'ad_manager.dart'; 
import 'admin_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _coins = 0;
  StreamSubscription<DocumentSnapshot>? _banCheckSub;

  @override
  void initState() {
    super.initState();
    _fetchCoins();
    _startBanListener();
  }

  @override
  void dispose() {
    _banCheckSub?.cancel();
    super.dispose();
  }

  void _startBanListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _banCheckSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data();
        final bool isBanned = data?['isBanned'] ?? false;

        if (isBanned) {
          await FirebaseAuth.instance.signOut();
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hesabınız askıya alınmıştır (banlandınız). 🚫'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    });
  }

  Future<void> _fetchCoins() async {
    final coins = await BambooEconomy.getCoins();
    if (mounted) {
      setState(() {
        _coins = coins;
      });
    }
  }

  Future<void> _checkAdminAndNavigate(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final bool isAdmin = data['isAdmin'] ?? false;

      if (!context.mounted) return;

      if (isAdmin) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu alana erişim yetkin yok! 🚫'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 5 : 3;

    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'Pomodoro',
        'icon': Icons.timer,
        'color': Colors.deepOrangeAccent,
        'screen': const PomodoroScreen(),
      },
      {
        'title': 'Bambu',
        'icon': Icons.forest_rounded,
        'color': Colors.greenAccent,
        'screen': const BambooScreen(),
      },
      {
        'title': 'Liderlik',
        'icon': Icons.emoji_events_rounded,
        'color': Colors.amberAccent,
        'screen': const LeaderboardScreen(),
      },
      {
        'title': 'Pano',
        'icon': Icons.push_pin,
        'color': Colors.amberAccent,
        'screen': const CorkboardScreen(),
      },
      {
        'title': 'Ezber',
        'icon': Icons.style_rounded,
        'color': Colors.deepPurpleAccent,
        'screen': const EzberScreen(),
      },
      {
        'title': 'Bilgi Kartı',
        'icon': Icons.note_alt_rounded,
        'color': Colors.tealAccent,
        'screen': const BilgiKartiScreen(),
      },
      {
        'title': 'Deneme Analiz',
        'icon': Icons.analytics_rounded,
        'color': Colors.pinkAccent,
        'screen': const DenemeAnalizScreen(),
      },
      {
        'title': 'Grafik',
        'icon': Icons.show_chart_rounded,
        'color': Colors.cyanAccent,
        'screen': const GrafikScreen(),
      },
      {
        'title': 'Konu Takip',
        'icon': Icons.checklist_rounded,
        'color': Colors.pinkAccent,
        'screen': const KonuTakipScreen(),
      },
      {
        'title': 'Haftalık Program',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.blueAccent,
        'screen': const HaftalikProgramScreen(),
      },
      {
        'title': 'Soru Biriktirici',
        'icon': Icons.camera_alt_rounded,
        'color': Colors.amberAccent,
        'screen': const SoruBiriktiriciScreen(),
      },
      {
        'title': 'PDF',
        'icon': Icons.picture_as_pdf_rounded,
        'color': Colors.tealAccent,
        'screen': const AdvancedPdfLibraryScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Bamboo'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: ProfileCache.notifier,
            builder: (context, profile, child) {
              final imagePath = profile['imagePath'];
              return IconButton(
                icon: CircleAvatar(
                  backgroundColor: const Color(0xFF2C2C2C),
                  backgroundImage: imagePath != null && File(imagePath).existsSync()
                      ? FileImage(File(imagePath))
                      : null,
                  child: imagePath == null || !File(imagePath).existsSync()
                      ? const Icon(Icons.person, color: Colors.cyanAccent, size: 22)
                      : null,
                ),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ),
        actions: [
          FutureBuilder(
            future: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return null;
              return await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            }(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
                final doc = snapshot.data;
                if (doc != null && doc.exists) {
                  final data = doc.data();
                  final bool isAdmin = data?['isAdmin'] ?? false;

                  if (isAdmin) {
                    return IconButton(
                      icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.pinkAccent),
                      tooltip: 'Yönetici Paneli',
                      onPressed: () => _checkAdminAndNavigate(context),
                    );
                  }
                }
              }
              return const SizedBox.shrink();
            },
          ),
          
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdRewardScreen()),
              );
              _fetchCoins();
            },
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amberAccent, width: 1),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '$_coins',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: GridView.builder(
              itemCount: menuItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final Color color = item['color'];

                return GestureDetector(
                  onTap: () {
                    AdManager.showInterstitialAd(() async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => item['screen']),
                      );
                      _fetchCoins();
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(item['icon'], color: color, size: 34),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['title'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: SizedBox(
          height: 60,
          child: BannerAdWidget(),
        ),
      ),
    );
  }
}