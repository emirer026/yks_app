import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileCache {
  static final ValueNotifier<Map<String, dynamic>> notifier = ValueNotifier({
    'username': 'Kullanıcı Adı',
    'field': 'SAY',
    'targetRank': '',
    'imagePath': null,
  });

  static Future<void> init() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
        if (doc.exists && doc.data() != null) {
          notifier.value = doc.data()!;
        }
      }
    } catch (_) {}
  }

  static void update(Map<String, dynamic> data) {
    notifier.value = data;
  }
}