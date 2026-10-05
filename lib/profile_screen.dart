import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_service.dart';
import 'profile_cache.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _targetRankController = TextEditingController();
  
  String _selectedField = 'SAY';
  final List<String> _fieldOptions = ['SAY', 'EA', 'SÖZ', 'TYT'];

  String? _imagePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get()
            .timeout(const Duration(seconds: 4));

        if (doc.exists && doc.data() != null) {
          var data = doc.data()!;
          setState(() {
            _usernameController.text = data['username'] ?? '';
            _targetRankController.text = data['targetRank'] ?? '';
            _selectedField = data['field'] ?? 'SAY';
            _imagePath = data['imagePath'];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Firestore'da yoksa başka hesabın verisi karışmasın, tertemiz boş gelsin
    setState(() {
      _usernameController.text = '';
      _targetRankController.text = '';
      _selectedField = 'SAY';
      _imagePath = null;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilirken bir hata oluştu.')),
      );
    }
  }

  Future<void> _saveProfileData() async {
    String enteredUsername = _usernameController.text.trim().toLowerCase().replaceAll(' ', '_');

    if (enteredUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı boş olamaz!')),
      );
      return;
    }

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // Kullanıcı adı başka birine ait mi kontrolü (Zaman aşımı korumalı)
      if (currentUid != null) {
        try {
          final usernameQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: enteredUsername)
              .get()
              .timeout(const Duration(seconds: 4));

          if (usernameQuery.docs.isNotEmpty) {
            bool isTakenBySomeoneElse = usernameQuery.docs.any((doc) => doc.id != currentUid);
            if (isTakenBySomeoneElse) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bu kullanıcı adı zaten alınmış!')),
              );
              return;
            }
          }
        } catch (e) {
          print("Firestore kontrol zaman aşımı/hatası: $e");
        }
      }

      Map<String, dynamic> data = {
        'username': enteredUsername,
        'targetRank': _targetRankController.text.trim(),
        'field': _selectedField,
        'imagePath': _imagePath,
      };

      // 1. Yerel Veritabanı ve Cache Güncelleme (Asla takılmaz)
      await UserDataService.saveModuleData('user_profile', jsonEncode(data));
      ProfileCache.update(data);
      
      // 2. Firestore'a Kaydetme (Zaman aşımı korumalı)
      if (currentUid != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .set(data, SetOptions(merge: true))
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          print("Firestore yazma zaman aşımı/hatası: $e");
        }
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil kaydedildi!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      print("GENEL KAYIT HATASI: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt başarısız: $e')),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _targetRankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Profil Özelleştirme'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF2C2C2C),
                    backgroundImage: _imagePath != null && File(_imagePath!).existsSync()
                        ? FileImage(File(_imagePath!))
                        : null,
                    child: _imagePath == null || !File(_imagePath!).existsSync()
                        ? const Icon(Icons.person, color: Colors.blueAccent, size: 55)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Kullanıcı Adı',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedField,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Alan',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
              items: _fieldOptions.map((String field) {
                return DropdownMenuItem<String>(
                  value: field,
                  child: Text(field, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedField = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _targetRankController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Hedef Sıralama',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveProfileData,
                child: const Text(
                  'Kaydet ve Çık',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}