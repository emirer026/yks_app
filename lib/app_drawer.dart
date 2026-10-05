import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_screen.dart';
import 'friends_screen.dart';
import 'profile_cache.dart';
import 'auth_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // ============================================================
  // OTURUM KAPATMA
  // ============================================================
  Future<void> _signOut(BuildContext context) async {
    try {
      // Firebase oturumunu kapat
      await FirebaseAuth.instance.signOut();

      // Local giriş bilgilerini ve beni hatırla verilerini temizle
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('is_logged_in');
      await prefs.remove('current_user_email');
      await prefs.remove('remember_me');
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      // Not: Sözleşme onayını (agreement_accepted) silmiyoruz ki 
      // kullanıcı tekrar giriş yaparken sözleşmeyi tekrar onaylamak zorunda kalmasın,
      // ama istersek onu da silebiliriz. Şimdilik sadece oturum anahtarlarını siliyoruz.

      if (!context.mounted) return;

      // AuthScreen'e git.
      // HomeScreen, Drawer ve diğer tüm eski sayfaları temizle.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Çıkış yapılırken bir hata oluştu: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // GERİ BİLDİRİM PENCERESİ
  // ============================================================
  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController =
        TextEditingController();

    String selectedCategory = 'Öneri';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),

              title: const Text(
                'Geri Bildirim Gönder',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),

              content: SizedBox(
                width: 300,

                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Konu Seçin',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    DropdownButton<String>(
                      value: selectedCategory,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      isExpanded: true,

                      items: [
                        'Öneri',
                        'Hata Bildirimi',
                        'Diğer',
                      ].map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),

                      onChanged: (newValue) {
                        if (newValue == null) return;

                        setStateDialog(() {
                          selectedCategory = newValue;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: feedbackController,
                      maxLines: 4,

                      style: const TextStyle(
                        color: Colors.white,
                      ),

                      decoration: InputDecoration(
                        hintText:
                            'Uygulamayı geliştirmemiz için fikirlerini yaz...',

                        hintStyle: const TextStyle(
                          color: Colors.white54,
                        ),

                        filled: true,
                        fillColor: const Color(0xFF121212),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                // İPTAL
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text(
                    'İptal',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),

                // GÖNDER
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),

                  onPressed: () async {
                    final String text =
                        feedbackController.text.trim();

                    if (text.isEmpty) return;

                    final user =
                        FirebaseAuth.instance.currentUser;

                    try {
                      await FirebaseFirestore.instance
                          .collection('feedbacks')
                          .add({
                        'userId': user?.uid ?? 'guest',
                        'category': selectedCategory,
                        'message': text,
                        'timestamp':
                            FieldValue.serverTimestamp(),
                        'appVersion': 'BETA',
                      });

                      if (!dialogContext.mounted) return;

                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Geri bildirimin için teşekkürler! 🚀',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Geri bildirim gönderilemedi: $e',
                          ),
                        ),
                      );
                    }
                  },

                  child: const Text(
                    'Gönder',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DRAWER
  // ============================================================
  @override
  Widget build(BuildContext context) {
    ProfileCache.init();

    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),

      child: ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: ProfileCache.notifier,

        builder: (context, profile, child) {
          final username =
              profile['username'] ?? 'Kullanıcı Adı';

          final field =
              profile['field'] ?? 'SAY';

          final imagePath =
              profile['imagePath'];

          return ListView(
            padding: EdgeInsets.zero,

            children: [
              // ==================================================
              // PROFİL BAŞLIĞI
              // ==================================================
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF121212),
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,

                  children: [
                    // PROFİL FOTOĞRAFI
                    CircleAvatar(
                      radius: 28,

                      backgroundColor:
                          const Color(0xFF2C2C2C),

                      backgroundImage:
                          imagePath != null &&
                                  File(imagePath)
                                      .existsSync()
                              ? FileImage(
                                  File(imagePath),
                                )
                              : null,

                      child:
                          imagePath == null ||
                                  !File(imagePath)
                                      .existsSync()
                              ? const Icon(
                                  Icons.person,
                                  color:
                                      Colors.blueAccent,
                                  size: 32,
                                )
                              : null,
                    ),

                    const SizedBox(width: 14),

                    // KULLANICI BİLGİLERİ
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        mainAxisAlignment:
                            MainAxisAlignment.center,

                        children: [
                          Text(
                            '@$username',

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                            ),

                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 2),

                          Text(
                            field,

                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // AYARLAR
                    IconButton(
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),

                      onPressed: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ==================================================
              // UYGULAMALARIM
              // ==================================================
              ListTile(
                leading: const Icon(
                  Icons.apps,
                  color: Colors.blueAccent,
                ),

                title: const Text(
                  'Uygulamalarım',

                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                onTap: () {
                  Navigator.pop(context);
                },
              ),

              // ==================================================
              // ARKADAŞLAR
              // ==================================================
              ListTile(
                leading: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.tealAccent,
                ),

                title: const Text(
                  'Arkadaşlar',

                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const FriendsScreen(),
                    ),
                  );
                },
              ),

              const Divider(
                color: Colors.white24,
                indent: 16,
                endIndent: 16,
              ),

              // ==================================================
              // GERİ BİLDİRİM
              // ==================================================
              ListTile(
                leading: const Icon(
                  Icons.feedback_outlined,
                  color: Colors.amberAccent,
                ),

                title: const Text(
                  'Geri Bildirim / Hata Bildir',

                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                subtitle: const Text(
                  'Bize fikirlerini ilet!',

                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                onTap: () {
                  Navigator.pop(context);

                  _showFeedbackDialog(context);
                },
              ),

              const Divider(
                color: Colors.white24,
                indent: 16,
                endIndent: 16,
              ),

              // ==================================================
              // ÇIKIŞ YAP
              // ==================================================
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                ),

                title: const Text(
                  'Çıkış Yap',

                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                subtitle: const Text(
                  'Oturumu sonlandır',

                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                onTap: () async {
                  await _signOut(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}