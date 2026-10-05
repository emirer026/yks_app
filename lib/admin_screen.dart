import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

  // users_data koleksiyonunu tek seferden dinleyip uid -> veri şeklinde
  // hafızada tutuyoruz. Liste ekranında her satır için ayrı ayrı sorgu
  // atmak yerine tek bir dinleyici kullanıyoruz.
  Map<String, Map<String, dynamic>> _usersDataMap = {};
  // uid -> username, şikayet listesinde isim göstermek için.
  final Map<String, String> _usernameCache = {};

  StreamSubscription<QuerySnapshot>? _usersDataSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _usersDataSub = _firestore.collection('users_data').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _usersDataMap = {
          for (final doc in snap.docs) doc.id: doc.data(),
        };
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _usersDataSub?.cancel();
    super.dispose();
  }

  // İki kullanıcı arasındaki gerçek sohbet ID'sini üretir.
  String _getChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  Future<String> _resolveUsername(String uid) async {
    if (uid.isEmpty) return 'Bilinmeyen';
    if (_usernameCache.containsKey(uid)) return _usernameCache[uid]!;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final name = (doc.data()?['username'] as String?)?.trim();
      final resolved = (name == null || name.isEmpty) ? uid : name;
      _usernameCache[uid] = resolved;
      return resolved;
    } catch (_) {
      return uid;
    }
  }

  // --- KULLANICI PROFİLİ (users koleksiyonu) GÜNCELLEME ---
  Future<void> _updateUserProfile(String userId, Map<String, dynamic> updatedData) async {
    await _firestore.collection('users').doc(userId).set(updatedData, SetOptions(merge: true));
  }

  // --- EKONOMİ VERİSİ (users_data koleksiyonu) GÜNCELLEME ---
  Future<void> _updateUserEconomy(String userId, Map<String, dynamic> updatedData) async {
    await _firestore.collection('users_data').doc(userId).set(updatedData, SetOptions(merge: true));
  }

  Future<void> _saveAllUserChanges({
    required String userId,
    required String username,
    required bool isBanned,
    required int coins,
    required int focusMinutes,
    required int waterCount,
    required int seedsCount,
  }) async {
    try {
      await Future.wait([
        _updateUserProfile(userId, {
          'username': username,
          'isBanned': isBanned,
        }),
        _updateUserEconomy(userId, {
          'bamboo_coins': coins,
          'bamboo_focus_minutes': focusMinutes,
          'bamboo_water_count': waterCount,
          'bamboo_seeds_count': seedsCount,
        }),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı başarıyla güncellendi! ✅'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncelleme hatası: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- KÖKÜNÜ KAZIYARAK KULLANICIYI VE TÜM İLİŞKİLİ VERİLERİNİ SİLME ---
  Future<void> _deleteUserCompletely(String userId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Kullanıcının Kökünü Kazı 🔥', style: TextStyle(color: Colors.redAccent)),
            content: const Text(
              'Bu işlem geri alınamaz!\n\n'
              'Kullanıcının;\n'
              '• Profil kaydı (users)\n'
              '• Ekonomi ve odak verileri (users_data)\n'
              '• Kendi arkadaş listesi ve diğer kullanıcıların listesindeki bağı (friends)\n'
              '• Sohbet geçmişleri ve mesajları (chats)\n'
              '• Hakkında açılan şikayetler (reports)\n\n'
              'tüm Firestore veritabanından kalıcı olarak silinecektir.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kökünü Kazı'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      // 1. Bu kullanıcının kendi altındaki 'friends' koleksiyonunu temizle
      final friendsSnapshot = await _firestore.collection('users').doc(userId).collection('friends').get();
      for (var doc in friendsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. DİĞER KULLANICILARIN arkadaş listesinden de bu kişiyi sil
      final allUsersSnapshot = await _firestore.collection('users').get();
      for (var userDoc in allUsersSnapshot.docs) {
        final friendDocRef = _firestore.collection('users').doc(userDoc.id).collection('friends').doc(userId);
        final friendDoc = await friendDocRef.get();
        if (friendDoc.exists) {
          await friendDocRef.delete();
        }
      }

      // 3. Bu kullanıcıya ait veya onunla yapılan sohbetleri (chats) ve mesajları temizle
      final chatsSnapshot = await _firestore.collection('chats').get();
      for (var chatDoc in chatsSnapshot.docs) {
        if (chatDoc.id.contains(userId)) {
          final messagesSnapshot = await chatDoc.reference.collection('messages').get();
          for (var msgDoc in messagesSnapshot.docs) {
            await msgDoc.reference.delete();
          }
          await chatDoc.reference.delete();
        }
      }

      // 4. Bu kullanıcıyla ilgili şikayetleri (reports) temizle
      final reportsAsReported = await _firestore.collection('reports').where('reportedUserId', isEqualTo: userId).get();
      for (var doc in reportsAsReported.docs) {
        await doc.reference.delete();
      }
      final reportsAsReporter = await _firestore.collection('reports').where('reporterId', isEqualTo: userId).get();
      for (var doc in reportsAsReporter.docs) {
        await doc.reference.delete();
      }

      // 5. Ana koleksiyonlardaki (users ve users_data) verileri tamamen uçur
      await Future.wait([
        _firestore.collection('users').doc(userId).delete(),
        _firestore.collection('users_data').doc(userId).delete(),
      ]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı ve tüm sohbet/arkadaşlık kalıntıları temizlendi! 🧹🔥'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kapsamlı silme hatası: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Kullanıcı Detay ve Yönetim Paneli Modal Penceresi
  void _openUserDetailModal(String userId, Map<String, dynamic> userProfileData) {
    final economyData = _usersDataMap[userId] ?? {};

    final usernameController = TextEditingController(text: userProfileData['username'] ?? '');
    final coinsController = TextEditingController(text: (economyData['bamboo_coins'] ?? 0).toString());
    final focusController = TextEditingController(text: (economyData['bamboo_focus_minutes'] ?? 0).toString());
    final waterController = TextEditingController(text: (economyData['bamboo_water_count'] ?? 0).toString());
    final seedsController = TextEditingController(text: (economyData['bamboo_seeds_count'] ?? 0).toString());
    bool isBanned = userProfileData['isBanned'] ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kullanıcı Yönetimi: ${userProfileData['current_user_email'] ?? userProfileData['email'] ?? userId}',
                      style: const TextStyle(color: Colors.pinkAccent, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'UID: $userId',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Kullanıcı Adı', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: coinsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: '🪙 Coin', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: focusController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: '⏳ Odak (dk)', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: waterController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: '💧 Su', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: seedsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: '🌰 Tohum', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hesabı Askıya Al (Banla)', style: TextStyle(color: Colors.white)),
                      subtitle: const Text(
                        'Bu bayrak etkinleştirildiğinde kullanıcı uygulamadayken '
                        'otomatik olarak oturumu kapatılır ve giriş ekranına yönlendirilir.',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                      ),
                      value: isBanned,
                      activeColor: Colors.redAccent,
                      onChanged: (val) {
                        setModalState(() => isBanned = val);
                      },
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),

                    // Arkadaşları Görüntüleme Bölümü
                    const Text('Arkadaş Listesi', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('users').doc(userId).collection('friends').snapshots(),
                        builder: (context, friendSnapshot) {
                          if (friendSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2));
                          }
                          if (!friendSnapshot.hasData || friendSnapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('Kayıtlı arkadaşı bulunmuyor.', style: TextStyle(color: Colors.white54, fontSize: 12)));
                          }
                          final friends = friendSnapshot.data!.docs;
                          return ListView.builder(
                            itemCount: friends.length,
                            itemBuilder: (context, index) {
                              final friendData = friends[index].data() as Map<String, dynamic>;
                              final friendUid = friends[index].id;
                              final friendUsername = friendData['username'] ?? 'Bilinmeyen Arkadaş';
                              return ListTile(
                                dense: true,
                                title: Text(friendUsername, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: Text(friendUid, style: const TextStyle(color: Colors.white30, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.cyanAccent, size: 18),
                                  tooltip: 'Mesaj Geçmişini İncele (Salt-Okunur)',
                                  onPressed: () {
                                    _openMessagesModal(userId, friendUid, friendUsername);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('İptal', style: TextStyle(color: Colors.white54)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            await _saveAllUserChanges(
                              userId: userId,
                              username: usernameController.text.trim(),
                              isBanned: isBanned,
                              coins: int.tryParse(coinsController.text) ?? 0,
                              focusMinutes: int.tryParse(focusController.text) ?? 0,
                              waterCount: int.tryParse(waterController.text) ?? 0,
                              seedsCount: int.tryParse(seedsController.text) ?? 0,
                            );
                            navigator.pop();
                          },
                          child: const Text('Değişiklikleri Kaydet'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openUserDetailModalById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bulunamadı (silinmiş olabilir).'), backgroundColor: Colors.red),
        );
        return;
      }
      if (!mounted) return;
      _openUserDetailModal(userId, doc.data() ?? {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı yüklenemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openMessagesModal(String userId, String friendId, String friendName) {
    final chatId = _getChatId(userId, friendId);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Mesaj Geçmişi: $friendName',
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('Salt-Okunur', style: TextStyle(fontSize: 10, color: Colors.amberAccent)),
                    backgroundColor: Colors.black45,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(300)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Bu iki kullanıcı arasında mesaj bulunmuyor.', style: TextStyle(color: Colors.white54)));
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msgData = messages[index].data() as Map<String, dynamic>;
                        final text = msgData['text'] ?? '';
                        final sender = msgData['senderId'] ?? '';
                        final isFromViewedUser = sender == userId;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isFromViewedUser ? Colors.pinkAccent.withValues(alpha: 0.08) : Colors.cyanAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            '[${isFromViewedUser ? "İncelenen" : friendName}]: $text',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateReportStatus(String reportId, String status) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({'status': status});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şikayet "$status" olarak işaretlendi.'), backgroundColor: Colors.blueGrey),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('reports').orderBy('timestamp', descending: true).limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Hiç şikayet bulunmuyor. 🎉', style: TextStyle(color: Colors.white54)));
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final doc = reports[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final reason = data['reason'] ?? 'Belirtilmemiş';
            final detail = (data['detail'] ?? '').toString();
            final messageText = data['messageText'] ?? '';
            final reporterId = (data['reporterId'] ?? '').toString();
            final reportedUserId = (data['reportedUserId'] ?? '').toString();

            Color statusColor = Colors.amberAccent;
            String statusLabel = 'Bekliyor';
            if (status == 'resolved') {
              statusColor = Colors.greenAccent;
              statusLabel = 'Çözüldü';
            } else if (status == 'dismissed') {
              statusColor = Colors.grey;
              statusLabel = 'Reddedildi';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (messageText.toString().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                      child: Text('"$messageText"', style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Ek açıklama: $detail', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  FutureBuilder<List<String>>(
                    future: Future.wait([_resolveUsername(reporterId), _resolveUsername(reportedUserId)]),
                    builder: (context, nameSnap) {
                      final names = nameSnap.data;
                      final reporterName = names != null ? names[0] : '...';
                      final reportedName = names != null ? names[1] : '...';
                      return Text(
                        'Şikayet eden: $reporterName   •   Şikayet edilen: $reportedName',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.cyanAccent)),
                        onPressed: reportedUserId.isEmpty ? null : () => _openUserDetailModalById(reportedUserId),
                        icon: const Icon(Icons.person_search, color: Colors.cyanAccent, size: 16),
                        label: const Text('Şikayet Edileni Görüntüle', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                      ),
                      if (status != 'resolved')
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.greenAccent)),
                          onPressed: () => _updateReportStatus(doc.id, 'resolved'),
                          icon: const Icon(Icons.check, color: Colors.greenAccent, size: 16),
                          label: const Text('Çözüldü', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                        ),
                      if (status != 'dismissed')
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey)),
                          onPressed: () => _updateReportStatus(doc.id, 'dismissed'),
                          icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                          label: const Text('Reddet', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'E-posta veya kullanıcı adı ile ara...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Hiç kullanıcı bulunamadı.', style: TextStyle(color: Colors.white54)));
              }

              final users = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final email = (data['current_user_email'] ?? data['email'] ?? '').toString().toLowerCase();
                final username = (data['username'] ?? '').toString().toLowerCase();
                return email.contains(_searchQuery) || username.contains(_searchQuery);
              }).toList();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrelenen Kullanıcı Sayısı: ${users.length}',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userDoc = users[index];
                          final userData = userDoc.data() as Map<String, dynamic>;
                          final userId = userDoc.id;

                          final economyData = _usersDataMap[userId] ?? {};

                          final email = userData['current_user_email'] ?? userData['email'] ?? 'Bilinmeyen E-posta';
                          final username = userData['username'] ?? 'İsimsiz';
                          final coins = economyData['bamboo_coins'] ?? 0;
                          final focusMins = economyData['bamboo_focus_minutes'] ?? 0;
                          final isBanned = userData['isBanned'] ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isBanned ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isBanned ? Colors.redAccent : Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isBanned) ...[
                                            const SizedBox(width: 8),
                                            const Text('BANLI', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ]
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Kullanıcı Adı: $username', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text('🪙 $coins', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                                          const SizedBox(width: 12),
                                          Text('⏳ $focusMins dk', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.manage_accounts, color: Colors.cyanAccent),
                                  tooltip: 'Profili ve Verileri İncele / Düzenle',
                                  onPressed: () => _openUserDetailModal(userId, userData),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  tooltip: 'Kullanıcının Kökünü Kazı',
                                  onPressed: () => _deleteUserCompletely(userId),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('🛠️ Bamboo Yönetici Paneli'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Kullanıcılar'),
            Tab(icon: Icon(Icons.flag), text: 'Şikayetler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }
}