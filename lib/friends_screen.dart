import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'user_data_service.dart';

// ==========================================
// SOSYAL SERVİS - Tüm Firestore mantığının
// tek merkezi. Arkadaşlık, engelleme, sohbet
// silme ve şikayet işlemleri burada toplanır.
// Böylece aynı mantık iki farklı yerde farklı
// şekilde tekrar yazılıp hataya açık hale
// gelmiyor.
// ==========================================
class SocialService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// İki kullanıcı arasındaki DM sohbet kimliğini üretir.
  static String chatIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  static String _blockDocId(String blockerUid, String blockedUid) =>
      '${blockerUid}_$blockedUid';

  /// A, B'yi engellemiş mi VEYA B, A'yı engellemiş mi? (çift yönlü kontrol)
  static Future<bool> isBlockedEitherWay(String uidA, String uidB) async {
    if (uidA == uidB) return false;
    try {
      final results = await Future.wait([
        _db.collection('blocks').doc(_blockDocId(uidA, uidB)).get(),
        _db.collection('blocks').doc(_blockDocId(uidB, uidA)).get(),
      ]);
      return results[0].exists || results[1].exists;
    } catch (_) {
      // Kontrol başarısız olursa güvenli tarafta kal: engelli varsay etme,
      // ama işlemi de durdurma; çağıran taraf gerekirse tekrar deneyebilir.
      return false;
    }
  }

  /// Bir sohbetin TÜM mesajlarını ve sohbet dokümanının kendisini siler.
  /// Ücretsiz sunucu kotasını şişirmemek için grup halinde (batch) siliniyor.
  static Future<void> deleteChatCompletely(String chatId) async {
    final messagesRef =
        _db.collection('chats').doc(chatId).collection('messages');
    while (true) {
      final snap = await messagesRef.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < 400) break;
    }
    try {
      await _db.collection('chats').doc(chatId).delete();
    } catch (_) {}
  }

  /// Arkadaşlıktan çıkarır VE aralarındaki DM geçmişini tamamen siler.
  static Future<void> removeFriend(String myUid, String friendUid) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(friendUid));
    batch.delete(_db
        .collection('users')
        .doc(friendUid)
        .collection('friends')
        .doc(myUid));
    await batch.commit();

    final chatId = chatIdFor(myUid, friendUid);
    await deleteChatCompletely(chatId);
  }

  static Future<void> _clearPendingRequestsBothWays(
      String uidA, String uidB) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('users')
        .doc(uidA)
        .collection('friend_requests')
        .doc(uidB));
    batch.delete(_db
        .collection('users')
        .doc(uidB)
        .collection('sent_requests')
        .doc(uidA));
    batch.delete(_db
        .collection('users')
        .doc(uidB)
        .collection('friend_requests')
        .doc(uidA));
    batch.delete(_db
        .collection('users')
        .doc(uidA)
        .collection('sent_requests')
        .doc(uidB));
    await batch.commit();
  }

  /// Kullanıcıyı engeller: arkadaşlıktan çıkarır, sohbeti siler,
  /// bekleyen tüm istekleri iptal eder, çift yönlü engel kaydı oluşturur.
  static Future<void> blockUser(
    String myUid,
    String targetUid,
    Map<String, dynamic> targetData,
  ) async {
    final blockId = _blockDocId(myUid, targetUid);
    final batch = _db.batch();
    batch.set(
      _db
          .collection('users')
          .doc(myUid)
          .collection('blocked')
          .doc(targetUid),
      {
        'username': targetData['username'] ?? 'İsimsiz',
        'field': targetData['field'] ?? 'SAY',
        'targetRank': targetData['targetRank'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      },
    );
    batch.set(_db.collection('blocks').doc(blockId), {
      'blockerId': myUid,
      'blockedId': targetUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    await _clearPendingRequestsBothWays(myUid, targetUid);
    await removeFriend(myUid, targetUid);
  }

  static Future<void> unblockUser(String myUid, String targetUid) async {
    final blockId = _blockDocId(myUid, targetUid);
    final batch = _db.batch();
    batch.delete(_db
        .collection('users')
        .doc(myUid)
        .collection('blocked')
        .doc(targetUid));
    batch.delete(_db.collection('blocks').doc(blockId));
    await batch.commit();
  }

  /// Mesaj şikayetini 'reports' koleksiyonuna yazar.
  static Future<String> reportMessage({
    required String chatId,
    required String messageId,
    required String reportedUserId,
    required String reporterId,
    required String messageText,
    required String reason,
    String details = '',
  }) async {
    final doc = await _db.collection('reports').add({
      'chatId': chatId,
      'messageId': messageId,
      'reportedUserId': reportedUserId,
      'reporterId': reporterId,
      'messageText': messageText,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _blockUsernameController =
      TextEditingController();

  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  // Sadece geniş ekranda (tablet/desktop) kullanılır.
  String? _selectedChatId;
  String? _selectedChatTitle;
  bool _selectedChatIsGroup = false;

  static const double _wideBreakpoint = 700;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _updateUserPresence(true);
  }

  @override
  void dispose() {
    _updateUserPresence(false);
    _tabController.dispose();
    _searchController.dispose();
    _blockUsernameController.dispose();
    super.dispose();
  }

  Future<void> _updateUserPresence(bool isOnline) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username',
              isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .get();

      var candidates = querySnapshot.docs
          .where((doc) => doc.id != currentUser?.uid)
          .toList();

      // Engelli kullanıcıları (iki yönde de) sonuçlardan çıkar.
      if (currentUser != null && candidates.isNotEmpty) {
        final blockChecks = await Future.wait(candidates
            .map((d) => SocialService.isBlockedEitherWay(currentUser.uid, d.id)));
        candidates = [
          for (int i = 0; i < candidates.length; i++)
            if (!blockChecks[i]) candidates[i],
        ];
      }

      if (!mounted) return;
      setState(() {
        _searchResults = candidates;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendFriendRequest(
      String targetUid, Map<String, dynamic> targetData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      if (await SocialService.isBlockedEitherWay(currentUser.uid, targetUid)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bu kullanıcıya istek gönderemezsin.')),
        );
        return;
      }

      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (!myDoc.exists) return;
      final myData = myDoc.data() ?? {};

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('friend_requests')
          .doc(currentUser.uid)
          .set({
        'username': myData['username'] ?? 'İsimsiz',
        'field': myData['field'] ?? 'SAY',
        'targetRank': myData['targetRank'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('sent_requests')
          .doc(targetUid)
          .set({
        'username': targetData['username'] ?? 'İsimsiz',
        'field': targetData['field'] ?? 'SAY',
        'targetRank': targetData['targetRank'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arkadaşlık isteği gönderildi!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İstek gönderilemedi: $e')),
      );
    }
  }

  Future<void> _cancelSentRequest(String targetUid) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('friend_requests')
          .doc(currentUser.uid)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('sent_requests')
          .doc(targetUid)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İstek geri çekildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İstek geri çekilemedi: $e')),
      );
    }
  }

  Future<void> _acceptRequest(
      String senderUid, Map<String, dynamic> senderData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final myData = myDoc.data() ?? {};

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(senderUid)
          .set({
        'username': senderData['username'],
        'field': senderData['field'],
        'targetRank': senderData['targetRank'],
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(senderUid)
          .collection('friends')
          .doc(currentUser.uid)
          .set({
        'username': myData['username'] ?? '',
        'field': myData['field'] ?? 'SAY',
        'targetRank': myData['targetRank'] ?? '',
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friend_requests')
          .doc(senderUid)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(senderUid)
          .collection('sent_requests')
          .doc(currentUser.uid)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arkadaş eklendi!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İstek kabul edilemedi: $e')),
      );
    }
  }

  Future<void> _rejectRequest(String senderUid) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friend_requests')
          .doc(senderUid)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(senderUid)
          .collection('sent_requests')
          .doc(currentUser.uid)
          .delete();
    } catch (_) {}
  }

  void _clearSelectedChatIfMatches(String chatId) {
    if (_selectedChatId == chatId) {
      setState(() {
        _selectedChatId = null;
        _selectedChatTitle = null;
      });
    }
  }

  Future<void> _handleRemoveFriend(String friendUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final chatId = SocialService.chatIdFor(currentUser.uid, friendUid);
    try {
      await SocialService.removeFriend(currentUser.uid, friendUid);
      _clearSelectedChatIfMatches(chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Arkadaşlıktan çıkarıldı, sohbet geçmişi silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  Future<void> _handleBlockFriend(
      String friendUid, Map<String, dynamic> friendData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final chatId = SocialService.chatIdFor(currentUser.uid, friendUid);
    try {
      await SocialService.blockUser(currentUser.uid, friendUid, friendData);
      _clearSelectedChatIfMatches(chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${friendData['username']} engellendi ve sohbet geçmişi silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Engelleme hatası: $e')),
      );
    }
  }

  Future<void> _handleBlockByUsername(String username) async {
    String targetUsername = username.trim().toLowerCase().replaceAll(' ', '_');
    if (targetUsername.isEmpty) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: targetUsername)
          .get();

      if (userQuery.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Böyle bir kullanıcı bulunamadı!')),
        );
        return;
      }

      final targetDoc = userQuery.docs.first;
      if (targetDoc.id == currentUser.uid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kendini engelleyemezsin!')),
        );
        return;
      }

      final targetData = targetDoc.data();
      final chatId = SocialService.chatIdFor(currentUser.uid, targetDoc.id);
      await SocialService.blockUser(currentUser.uid, targetDoc.id, targetData);
      _clearSelectedChatIfMatches(chatId);

      _blockUsernameController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${targetData['username']} engellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  Future<void> _handleUnblockUser(String targetUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await SocialService.unblockUser(currentUser.uid, targetUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Engel kaldırıldı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Engel kaldırılamadı: $e')),
      );
    }
  }

  Future<void> _getOrCreateDmChatId(
      String friendUid, String friendUsername, bool isWide) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (await SocialService.isBlockedEitherWay(currentUser.uid, friendUid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kullanıcıyla sohbet edemezsin.')),
      );
      return;
    }

    final chatId = SocialService.chatIdFor(currentUser.uid, friendUid);

    final chatDoc =
        await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'users': [currentUser.uid, friendUid],
        'isGroup': false,
        'lastMessage': 'Sohbet başlatıldı',
        'lastTimestamp': Timestamp.now(),
        'unread_${currentUser.uid}': 0,
        'unread_$friendUid': 0,
      });
    }

    if (isWide) {
      setState(() {
        _selectedChatId = chatId;
        _selectedChatTitle = friendUsername;
        _selectedChatIsGroup = false;
      });
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: chatId,
            chatTitle: friendUsername,
            isGroup: false,
          ),
        ),
      );
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final TextEditingController groupNameController = TextEditingController();
    Set<String> selectedUids = {};

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Yeni Grup Kur',
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 300,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      controller: groupNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Grup Adı',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Üye Seç',
                          style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .collection('friends')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          var friends = snapshot.data!.docs;
                          if (friends.isEmpty) {
                            return const Center(
                                child: Text('Eklenecek arkadaşın yok.',
                                    style: TextStyle(color: Colors.white54)));
                          }
                          return ListView.builder(
                            itemCount: friends.length,
                            itemBuilder: (context, index) {
                              var friendDoc = friends[index];
                              var friendData =
                                  friendDoc.data() as Map<String, dynamic>;
                              String friendUid = friendDoc.id;
                              bool isSelected =
                                  selectedUids.contains(friendUid);

                              return CheckboxListTile(
                                title: Text(friendData['username'] ?? 'İsimsiz',
                                    style:
                                        const TextStyle(color: Colors.white)),
                                value: isSelected,
                                activeColor: Colors.blueAccent,
                                checkColor: Colors.white,
                                onChanged: (val) {
                                  setStateDialog(() {
                                    if (val == true) {
                                      selectedUids.add(friendUid);
                                    } else {
                                      selectedUids.remove(friendUid);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('İptal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    String groupName = groupNameController.text.trim();
                    if (groupName.isEmpty || selectedUids.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Grup adı ve en az bir üye seçmelisin!')),
                      );
                      return;
                    }

                    List<String> members = [currentUser.uid, ...selectedUids];
                    Map<String, dynamic> unreadMap = {};
                    for (var uid in members) {
                      unreadMap['unread_$uid'] = 0;
                    }

                    try {
                      var chatRef =
                          await FirebaseFirestore.instance.collection('chats').add({
                        'isGroup': true,
                        'groupName': groupName,
                        'adminId': currentUser.uid,
                        'users': members,
                        'lastMessage': 'Grup oluşturuldu',
                        'lastTimestamp': Timestamp.now(),
                        ...unreadMap,
                      });

                      Navigator.pop(context);
                      final width = MediaQuery.of(context).size.width;
                      if (width >= _wideBreakpoint) {
                        setState(() {
                          _selectedChatId = chatRef.id;
                          _selectedChatTitle = groupName;
                          _selectedChatIsGroup = true;
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: chatRef.id,
                              chatTitle: groupName,
                              isGroup: true,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Grup kurulamadı: $e')),
                      );
                    }
                  },
                  child:
                      const Text('Oluştur', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _unreadBadge(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );

  Widget _chatTile({
    required bool isSelected,
    required Widget leading,
    required String title,
    required String subtitle,
    required int unread,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    return Container(
      color: isSelected ? const Color(0xFF2C2C2C) : Colors.transparent,
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: subtitleColor ?? (unread > 0 ? Colors.white : Colors.white54),
            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: unread > 0 ? _unreadBadge(unread) : null,
        onTap: onTap,
      ),
    );
  }

  // Sohbet/grup listesi paneli. Geniş ekranda sabit sol panel, telefonda
  // "Sohbet" sekmesinin tamamı olarak kullanılır.
  Widget _buildChatListPanel(User currentUser, {required bool isWide}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.group_add, size: 18, color: Colors.blueAccent),
            label: const Text('Yeni Grup Kur'),
            onPressed: _showCreateGroupDialog,
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2C2C2C)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('users', arrayContains: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent));
              }
              var chats = snapshot.data!.docs;

              if (chats.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Henüz aktif sohbetin veya grubun yok.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              chats.sort((a, b) {
                var aData = a.data() as Map<String, dynamic>;
                var bData = b.data() as Map<String, dynamic>;
                Timestamp? aTime = aData['lastTimestamp'] as Timestamp?;
                Timestamp? bTime = bData['lastTimestamp'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              return ListView.separated(
                itemCount: chats.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0xFF232323)),
                itemBuilder: (context, index) {
                  var chatDoc = chats[index];
                  var chatData = chatDoc.data() as Map<String, dynamic>;
                  String chatId = chatDoc.id;
                  bool isGroup = chatData['isGroup'] ?? false;
                  int unreadCount = chatData['unread_${currentUser.uid}'] ?? 0;
                  String lastMessage = chatData['lastMessage'] ?? '';

                  void openChat(String title) {
                    if (isWide) {
                      setState(() {
                        _selectedChatId = chatId;
                        _selectedChatTitle = title;
                        _selectedChatIsGroup = isGroup;
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            chatId: chatId,
                            chatTitle: title,
                            isGroup: isGroup,
                          ),
                        ),
                      );
                    }
                  }

                  if (isGroup) {
                    String groupName = chatData['groupName'] ?? 'Grup';
                    bool isSelected = isWide && _selectedChatId == chatId;

                    return _chatTile(
                      isSelected: isSelected,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF2C2C2C),
                        child: Icon(Icons.group, color: Colors.blueAccent),
                      ),
                      title: groupName,
                      subtitle: lastMessage,
                      unread: unreadCount,
                      onTap: () => openChat(groupName),
                    );
                  } else {
                    List users = chatData['users'] ?? [];
                    String otherUid = users
                        .firstWhere((id) => id != currentUser.uid, orElse: () => '');

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUid)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        var userData =
                            userSnapshot.data?.data() as Map<String, dynamic>?;
                        String username = userData?['username'] ?? 'İsimsiz';
                        bool isOnline = userData?['isOnline'] ?? false;
                        bool isStudying = userData?['isStudying'] ?? false;
                        bool isSelected = isWide && _selectedChatId == chatId;

                        return _chatTile(
                          isSelected: isSelected,
                          leading: Stack(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFF2C2C2C),
                                child: Icon(Icons.person, color: Colors.blueAccent),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF181818), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: username,
                          subtitle: isStudying ? 'Derste' : lastMessage,
                          subtitleColor: isStudying ? Colors.redAccent : null,
                          unread: unreadCount,
                          onTap: () => openChat(username),
                        );
                      },
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab(User? currentUser, bool isWide) {
    if (currentUser == null) {
      return const Center(
          child: Text('Oturum açılmadı.', style: TextStyle(color: Colors.white54)));
    }

    if (!isWide) {
      // Telefon: tam ekran liste, dokununca yeni sayfa açılır.
      return _buildChatListPanel(currentUser, isWide: false);
    }

    // Tablet/desktop: kalıcı iki panelli görünüm.
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Container(
            color: const Color(0xFF181818),
            child: _buildChatListPanel(currentUser, isWide: true),
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF2C2C2C)),
        Expanded(
          child: _selectedChatId == null
              ? const Center(
                  child: Text(
                    'Sohbet etmek için soldan bir sohbet seç.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ChatBodyWidget(
                  key: ValueKey(_selectedChatId),
                  chatId: _selectedChatId!,
                  chatTitle: _selectedChatTitle!,
                  isGroup: _selectedChatIsGroup,
                  onChatClosed: () {
                    setState(() {
                      _selectedChatId = null;
                      _selectedChatTitle = null;
                    });
                  },
                ),
        ),
      ],
    );
  }

  Widget _responsiveWrap(Widget child, bool isWide) {
    if (!isWide) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _wideBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Sosyal ve Arkadaşlar'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              child: currentUser == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_rounded,
                            color: Colors.blueAccent, size: 22),
                        SizedBox(height: 4),
                        Text('Sohbet', style: TextStyle(fontSize: 12)),
                      ],
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .where('users', arrayContains: currentUser.uid)
                          .snapshots(),
                      builder: (context, chatSnap) {
                        int totalUnread = 0;
                        if (chatSnap.hasData) {
                          for (var doc in chatSnap.data!.docs) {
                            var data = doc.data() as Map<String, dynamic>;
                            totalUnread +=
                                (data['unread_${currentUser.uid}'] ?? 0) as int;
                          }
                        }

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.chat_bubble_rounded,
                                    color: Colors.blueAccent, size: 22),
                                if (totalUnread > 0)
                                  Positioned(
                                    right: -10,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(
                                          minWidth: 16, minHeight: 16),
                                      child: Text(
                                        totalUnread > 99 ? '99+' : '$totalUnread',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Sohbet', style: TextStyle(fontSize: 12)),
                          ],
                        );
                      },
                    ),
            ),
            const Tab(icon: Icon(Icons.people, color: Colors.blueAccent), text: 'Arkadaşlar'),
            const Tab(icon: Icon(Icons.person_add, color: Colors.greenAccent), text: 'Arkadaş Ekle'),
            Tab(
              child: currentUser == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1, color: Colors.amberAccent, size: 22),
                        SizedBox(height: 4),
                        Text('İstekler', style: TextStyle(fontSize: 12)),
                      ],
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .collection('friend_requests')
                          .snapshots(),
                      builder: (context, snapshot) {
                        int count = snapshot.data?.docs.length ?? 0;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.person_add_alt_1,
                                    color: Colors.amberAccent, size: 22),
                                if (count > 0)
                                  Positioned(
                                    right: -10,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(
                                          minWidth: 16, minHeight: 16),
                                      child: Text(
                                        count > 99 ? '99+' : '$count',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('İstekler', style: TextStyle(fontSize: 12)),
                          ],
                        );
                      },
                    ),
            ),
            const Tab(icon: Icon(Icons.block, color: Colors.redAccent), text: 'Engelliler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. SOHBET SEKMESİ
          _buildChatTab(currentUser, isWide),

          // 2. ARKADAŞLAR SEKMESİ
          currentUser == null
              ? const Center(
                  child: Text('Oturum açılmadı.', style: TextStyle(color: Colors.white54)))
              : _responsiveWrap(
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('friends')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('Henüz ekli arkadaşın yok.',
                              style: TextStyle(color: Colors.white54, fontSize: 16)),
                        );
                      }
                      var friends = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          var doc = friends[index];
                          var data = doc.data() as Map<String, dynamic>;
                          var friendUid = doc.id;
                          var friendUsername = data['username'] ?? 'İsimsiz';

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF2C2C2C),
                                child: Icon(Icons.person, color: Colors.blueAccent),
                              ),
                              title: Text(
                                friendUsername,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Alan: ${data['field'] ?? 'SAY'}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline,
                                        color: Colors.blueAccent),
                                    onPressed: () async {
                                      await _getOrCreateDmChatId(
                                          friendUid, friendUsername, isWide);
                                      if (isWide) _tabController.animateTo(0);
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                                    color: const Color(0xFF1E1E1E),
                                    onSelected: (value) {
                                      if (value == 'remove') {
                                        _handleRemoveFriend(friendUid);
                                      } else if (value == 'block') {
                                        _handleBlockFriend(friendUid, data);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Arkadaşı Çıkar',
                                            style: TextStyle(color: Colors.white)),
                                      ),
                                      const PopupMenuItem(
                                        value: 'block',
                                        child: Text('Engelle',
                                            style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () async {
                                await _getOrCreateDmChatId(friendUid, friendUsername, isWide);
                                if (isWide) _tabController.animateTo(0);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                  isWide,
                ),

          // 3. ARKADAŞ EKLE SEKMESİ
          _responsiveWrap(
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: _searchUsers,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı adı ile ara...',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isSearching
                        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                        : _searchController.text.trim().isEmpty
                            ? currentUser == null
                                ? const Center(
                                    child: Text('Oturum açılmadı.',
                                        style: TextStyle(color: Colors.white54)))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Gönderilen İstekler',
                                          style: TextStyle(
                                              color: Colors.amberAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(currentUser.uid)
                                              .collection('sent_requests')
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData ||
                                                snapshot.data!.docs.isEmpty) {
                                              return const Center(
                                                  child: Text('Bekleyen gönderilen istek yok.',
                                                      style: TextStyle(color: Colors.white54)));
                                            }
                                            var sentDocs = snapshot.data!.docs;
                                            return ListView.builder(
                                              itemCount: sentDocs.length,
                                              itemBuilder: (context, index) {
                                                var sentData =
                                                    sentDocs[index].data() as Map<String, dynamic>;
                                                var targetUid = sentDocs[index].id;

                                                return Card(
                                                  color: const Color(0xFF1E1E1E),
                                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12)),
                                                  child: ListTile(
                                                    leading: const CircleAvatar(
                                                      backgroundColor: Color(0xFF2C2C2C),
                                                      child: Icon(Icons.hourglass_top,
                                                          color: Colors.amberAccent),
                                                    ),
                                                    title: Text(sentData['username'] ?? 'İsimsiz',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold)),
                                                    subtitle: Text(
                                                        'Alan: ${sentData['field'] ?? 'SAY'}',
                                                        style: const TextStyle(color: Colors.white54)),
                                                    trailing: TextButton(
                                                      style: TextButton.styleFrom(
                                                          foregroundColor: Colors.redAccent),
                                                      onPressed: () => _cancelSentRequest(targetUid),
                                                      child: const Text('Geri Çek'),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                            : _searchResults.isEmpty
                                ? const Center(
                                    child: Text('Kullanıcı bulunamadı.',
                                        style: TextStyle(color: Colors.white54)))
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      var doc = _searchResults[index];
                                      var data = doc.data() as Map<String, dynamic>;
                                      return Card(
                                        color: const Color(0xFF1E1E1E),
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFF2C2C2C),
                                            child: Icon(Icons.person, color: Colors.blueAccent),
                                          ),
                                          title: Text(data['username'] ?? 'İsimsiz',
                                              style: const TextStyle(
                                                  color: Colors.white, fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                              'Alan: ${data['field'] ?? 'SAY'} | Hedef: ${data['targetRank'] ?? '-'}',
                                              style: const TextStyle(color: Colors.white54)),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.person_add, color: Colors.greenAccent),
                                            onPressed: () => _sendFriendRequest(doc.id, data),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
            isWide,
          ),

          // 4. İSTEKLER SEKMESİ
          currentUser == null
              ? const Center(
                  child: Text('Oturum açılmadı.', style: TextStyle(color: Colors.white54)))
              : _responsiveWrap(
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('friend_requests')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('Bekleyen arkadaşlık isteği yok.',
                                style: TextStyle(color: Colors.white54, fontSize: 16)));
                      }
                      var requests = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          var data = requests[index].data() as Map<String, dynamic>;
                          var senderUid = requests[index].id;

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF2C2C2C),
                                child: Icon(Icons.person_add_alt_1, color: Colors.amberAccent),
                              ),
                              title: Text(data['username'] ?? 'İsimsiz',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Alan: ${data['field'] ?? 'SAY'} | Hedef: ${data['targetRank'] ?? '-'}',
                                  style: const TextStyle(color: Colors.white54)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.greenAccent),
                                    onPressed: () => _acceptRequest(senderUid, data),
                                    tooltip: 'Kabul Et',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.redAccent),
                                    onPressed: () => _rejectRequest(senderUid),
                                    tooltip: 'Reddet',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  isWide,
                ),

          // 5. ENGELLENENLER SEKMESİ
          _responsiveWrap(
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _blockUsernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Engellenecek kullanıcı adı...',
                            labelStyle: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            prefixIcon: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () => _handleBlockByUsername(_blockUsernameController.text),
                        child: const Text('Engelle', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: currentUser == null
                        ? const Center(
                            child: Text('Oturum açılmadı.', style: TextStyle(color: Colors.white54)))
                        : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .collection('blocked')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.block, color: Colors.redAccent, size: 48),
                                      SizedBox(height: 8),
                                      Text('Engellenen kimse yok.',
                                          style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }

                              var blockedDocs = snapshot.data!.docs;
                              return ListView.builder(
                                itemCount: blockedDocs.length,
                                itemBuilder: (context, index) {
                                  var blockedData =
                                      blockedDocs[index].data() as Map<String, dynamic>;
                                  var blockedUid = blockedDocs[index].id;

                                  return Card(
                                    color: const Color(0xFF1E1E1E),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Color(0xFF2C2C2C),
                                        child: Icon(Icons.block, color: Colors.redAccent, size: 20),
                                      ),
                                      title: Text(blockedData['username'] ?? 'İsimsiz',
                                          style: const TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.bold)),
                                      subtitle: Text('Alan: ${blockedData['field'] ?? 'SAY'}',
                                          style: const TextStyle(color: Colors.white54)),
                                      trailing: TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                        icon: const Icon(Icons.lock_open, size: 16),
                                        label: const Text('Engel Kaldır', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _handleUnblockUser(blockedUid),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            isWide,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TELEFON İÇİN TAM EKRAN SOHBET SAYFASI
// (Drawer yerine normal push/pop navigasyonu)
// ==========================================
class ChatPage extends StatelessWidget {
  final String chatId;
  final String chatTitle;
  final bool isGroup;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(chatTitle, style: const TextStyle(fontSize: 16)),
      ),
      body: ChatBodyWidget(
        chatId: chatId,
        chatTitle: chatTitle,
        isGroup: isGroup,
        onChatClosed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

// ==========================================
// SOHBET İÇERİK (MESSAGE BODY) WIDGETI
// ==========================================
class ChatBodyWidget extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final bool isGroup;
  final VoidCallback? onChatClosed;

  const ChatBodyWidget({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.isGroup,
    this.onChatClosed,
  });

  @override
  State<ChatBodyWidget> createState() => _ChatBodyWidgetState();
}

class _ChatBodyWidgetState extends State<ChatBodyWidget> {
  final TextEditingController _messageController = TextEditingController();

  Map<String, dynamic>? _replyingToMessage;
  DocumentSnapshot? _editingMessageDoc;

  static const List<String> _reportReasons = [
    'Uygunsuz İçerik',
    'Taciz / Zorbalık',
    'Spam',
    'Nefret Söylemi',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _resetUnreadCount();
  }

  @override
  void didUpdateWidget(covariant ChatBodyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      _resetUnreadCount();
      setState(() {
        _replyingToMessage = null;
        _editingMessageDoc = null;
        _messageController.clear();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _resetUnreadCount() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'unread_$currentUid': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendSystemMessage(String text) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': 'system',
      'text': text,
      'type': 'system',
      'timestamp': FieldValue.serverTimestamp(),
    });

    var chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (chatDoc.exists) {
      List users = chatDoc.data()?['users'] ?? [];
      Map<String, dynamic> updateData = {
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      };
      for (var uid in users) {
        if (uid != currentUid) {
          updateData['unread_$uid'] = FieldValue.increment(1);
        }
      }
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update(updateData);
    }
  }

  Future<void> _sendMessage(
      {String type = 'text',
      String textPayload = '',
      Map<String, dynamic>? moduleData,
      List<String>? itemsPayload}) async {
    final text = textPayload.isNotEmpty ? textPayload : _messageController.text.trim();
    if (text.isEmpty && type == 'text' && moduleData == null) return;

    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    try {
      if (_editingMessageDoc != null) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc(_editingMessageDoc!.id)
            .update({
          'text': text,
          'isEdited': true,
        });
        setState(() {
          _editingMessageDoc = null;
        });
      } else {
        Map<String, dynamic> messageData = {
          'senderId': currentUid,
          'text': text,
          'type': type,
          'timestamp': FieldValue.serverTimestamp(),
          'isEdited': false,
          'reactions': {},
          if (moduleData != null) 'moduleData': moduleData,
          if (itemsPayload != null) 'itemsPayload': itemsPayload,
        };

        if (_replyingToMessage != null) {
          messageData['replyTo'] = {
            'text': _replyingToMessage!['text'],
            'senderName': _replyingToMessage!['senderName'],
          };
        }

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add(messageData);

        var chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
        if (chatDoc.exists) {
          List users = chatDoc.data()?['users'] ?? [];
          Map<String, dynamic> updateData = {
            'lastMessage': type == 'text' ? text : '[Paylaşım]',
            'lastTimestamp': FieldValue.serverTimestamp(),
          };
          for (var uid in users) {
            if (uid != currentUid) {
              updateData['unread_$uid'] = FieldValue.increment(1);
            }
          }
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update(updateData);
        }

        setState(() {
          _replyingToMessage = null;
        });
      }

      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }

  void _showInlineEmojiPicker() {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🚀', '🔥', '👏', '🎯', '📚'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hızlı Emoji Ekle',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _messageController.text += emoji;
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSaveSelectionDialog(
      Map<String, dynamic> moduleData, List<dynamic> itemsPayload) async {
    Set<String> chosenItems = {};
    List<String> items = itemsPayload.map((e) => e.toString()).toList();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Kaydetmek İstediklerini Seç', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 300,
                height: 300,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    String item = items[index];
                    bool isChecked = chosenItems.contains(item);
                    return CheckboxListTile(
                      title: Text(item, style: const TextStyle(color: Colors.white)),
                      value: isChecked,
                      activeColor: Colors.greenAccent,
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            chosenItems.add(item);
                          } else {
                            chosenItems.remove(item);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  onPressed: () async {
                    if (chosenItems.isEmpty) return;
                    Navigator.pop(context);

                    String moduleKey = moduleData['moduleKey'];
                    final now = DateTime.now();
                    String dateStr = '${now.day}.${now.month}.${now.year}';
                    String formattedContent =
                        '--- ${widget.chatTitle} ($dateStr) ---\n${chosenItems.join('\n')}';

                    await UserDataService.saveModuleData(moduleKey, formattedContent);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Seçilen öğeler programına kaydedildi! 🚀',
                              style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('Seçilenleri Kaydet', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddMemberDialog(List currentUsers) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    Set<String> selectedUids = {};

    var myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    String myName = myDoc.data()?['username'] ?? 'Bir üye';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Gruba Üye Ekle', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 300,
                height: 380,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUid)
                      .collection('friends')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var friends =
                        snapshot.data!.docs.where((doc) => !currentUsers.contains(doc.id)).toList();
                    if (friends.isEmpty) {
                      return const Center(
                          child: Text('Eklenecek yeni arkadaşın yok veya hepsi grupta.',
                              style: TextStyle(color: Colors.white54), textAlign: TextAlign.center));
                    }
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        var friendData = friends[index].data() as Map<String, dynamic>;
                        String friendUid = friends[index].id;
                        bool isSelected = selectedUids.contains(friendUid);

                        return CheckboxListTile(
                          title: Text(friendData['username'] ?? 'İsimsiz', style: const TextStyle(color: Colors.white)),
                          value: isSelected,
                          activeColor: Colors.blueAccent,
                          checkColor: Colors.white,
                          onChanged: (val) {
                            setStateDialog(() {
                              if (val == true) {
                                selectedUids.add(friendUid);
                              } else {
                                selectedUids.remove(friendUid);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    if (selectedUids.isEmpty) return;

                    Navigator.pop(context);

                    List newUsers = List.from(currentUsers)..addAll(selectedUids);
                    Map<String, dynamic> updateData = {'users': newUsers};
                    for (var uid in selectedUids) {
                      updateData['unread_$uid'] = 0;
                    }

                    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update(updateData);

                    for (var uid in selectedUids) {
                      var fDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                      String fName = fDoc.data()?['username'] ?? 'Biri';
                      await _sendSystemMessage('$fName, $myName tarafından eklendi.');
                    }
                  },
                  child: const Text('Ekle', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showGroupDetailsDialog() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const AlertDialog(
                backgroundColor: Color(0xFF1E1E1E),
                content: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
              );
            }

            var chatData = snapshot.data!.data() as Map<String, dynamic>;
            List users = chatData['users'] ?? [];
            String adminId = chatData['adminId'] ?? '';
            String groupName = chatData['groupName'] ?? 'Grup';

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text('$groupName - Üyeler', style: const TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 320,
                height: 420,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                          foregroundColor: Colors.blueAccent,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Yeni Üye Ekle'),
                        onPressed: () => _showAddMemberDialog(users),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          String memberUid = users[index];
                          bool isAdmin = memberUid == adminId;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(memberUid).get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const ListTile(title: Text('Yükleniyor...', style: TextStyle(color: Colors.white54)));
                              }
                              var memberData = userSnapshot.data!.data() as Map<String, dynamic>?;
                              String username = memberData?['username'] ?? 'İsimsiz';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAdmin ? Colors.amberAccent : Colors.blueAccent,
                                  child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.black),
                                ),
                                title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(isAdmin ? 'Grup Kurucusu (Admin)' : 'Üye', style: TextStyle(color: isAdmin ? Colors.amberAccent : Colors.white54, fontSize: 12)),
                                trailing: currentUid == adminId && memberUid != currentUid
                                    ? IconButton(
                                        icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                        tooltip: 'Üyeyi At',
                                        onPressed: () async {
                                          users.remove(memberUid);
                                          
                                          // Eğer grupta kimse kalmadıysa grubu tamamen sil
                                          if (users.isEmpty) {
                                            Navigator.pop(context); // Diyalogu kapat
                                            await SocialService.deleteChatCompletely(widget.chatId);
                                            if (widget.onChatClosed != null) {
                                              widget.onChatClosed!();
                                            }
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Grupta kimse kalmadığı için grup silindi.')),
                                              );
                                            }
                                            return;
                                          }

                                          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                                            'users': users,
                                            'unread_$memberUid': FieldValue.delete(),
                                          });

                                          var myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                                          String adminName = myDoc.data()?['username'] ?? 'Admin';
                                          await _sendSystemMessage('$username, $adminName tarafından gruptan çıkarıldı.');

                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('$username gruptan atıldı.')),
                                            );
                                          }
                                        },
                                      )
                                    : (currentUid == adminId && memberUid == currentUid
                                        ? const Text('(Sen)', style: TextStyle(color: Colors.grey))
                                        : null),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    if (currentUid == adminId)
                      Column(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Adminliği Başkasına Devret'),
                            onPressed: () {
                              Navigator.pop(context);
                              _showTransferAdminDialog(users, adminId);
                            },
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Grubu Herkes İçin Sil'),
                            onPressed: () async {
                              Navigator.pop(context);
                              bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text('Grubu Sil', style: TextStyle(color: Colors.white)),
                                  content: const Text('Bu grubu tamamen silmek istediğinize emin misiniz? Tüm mesajlar silinecektir.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Sil', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await SocialService.deleteChatCompletely(widget.chatId);
                                if (widget.onChatClosed != null) {
                                  widget.onChatClosed!();
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Grup tamamen silindi.')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: const Text('Gruptan Ayrıl'),
                      onPressed: () async {
                        Navigator.pop(context);

                        var myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                        String myName = myDoc.data()?['username'] ?? 'Bir üye';

                        users.remove(currentUid);
                        if (users.isEmpty) {
                          await SocialService.deleteChatCompletely(widget.chatId);
                        } else {
                          String newAdminId = adminId;
                          if (currentUid == adminId && users.isNotEmpty) {
                            newAdminId = users.first;
                          }
                          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                            'users': users,
                            'adminId': newAdminId,
                            'unread_$currentUid': FieldValue.delete(),
                          });
                          await _sendSystemMessage('$myName gruptan ayrıldı.');
                        }

                        if (widget.onChatClosed != null) {
                          widget.onChatClosed!();
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gruptan ayrıldınız.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showTransferAdminDialog(List users, String currentAdminId) async {
    List otherMembers = users.where((u) => u != currentAdminId).toList();
    if (otherMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devredebileceğin başka üye yok!')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Adminliği Devret', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            height: 250,
            child: ListView.builder(
              itemCount: otherMembers.length,
              itemBuilder: (context, index) {
                String memberUid = otherMembers[index];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(memberUid).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    var data = snapshot.data!.data() as Map<String, dynamic>?;
                    String username = data?['username'] ?? 'İsimsiz';

                    return ListTile(
                      title: Text(username, style: const TextStyle(color: Colors.white)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                            'adminId': memberUid,
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Adminlik $username kişisine devredildi!')),
                          );
                        },
                        child: const Text('Seç'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDeleteMessage(String messageId, String senderId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (senderId != currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yalnızca kendi mesajlarınızı silebilirsiniz.')),
      );
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Mesajı Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc(messageId)
            .delete();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: $e')),
        );
      }
    }
  }

  Future<void> _toggleReaction(
      String messageId, String emoji, Map<String, dynamic>? existingReactions) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    Map<String, dynamic> reactions = existingReactions != null ? Map.from(existingReactions) : {};
    List<dynamic> users = reactions[emoji] != null ? List.from(reactions[emoji]) : [];

    if (users.contains(currentUid)) {
      users.remove(currentUid);
      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }
    } else {
      users.add(currentUid);
      reactions[emoji] = users;
    }

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions': reactions});
    } catch (_) {}
  }

  void _showEmojiPicker(String messageId, Map<String, dynamic>? currentReactions) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🚀', '🔥'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Emoji Tepkisi Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _toggleReaction(messageId, emoji, currentReactions);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // ŞİKAYET MODÜLÜ
  // ============================
  Future<void> _showReportDialog(
      DocumentSnapshot doc, Map<String, dynamic> data, String messageText) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final reportedUserId = data['senderId'] as String? ?? '';
    if (reportedUserId.isEmpty || reportedUserId == 'system') return;

    String selectedReason = _reportReasons.first;
    final detailsController = TextEditingController();
    bool alsoBlock = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Mesajı Şikayet Et', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        messageText.isEmpty ? '[İçerik]' : '"$messageText"',
                        style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Sebep', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                    ..._reportReasons.map((r) => RadioListTile<String>(
                          value: r,
                          groupValue: selectedReason,
                          activeColor: Colors.redAccent,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(r, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          onChanged: (v) => setStateDialog(() => selectedReason = v ?? selectedReason),
                        )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: detailsController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ek açıklama (isteğe bağlı)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    CheckboxListTile(
                      value: alsoBlock,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.redAccent,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Bu kullanıcıyı da engelle', style: TextStyle(color: Colors.white, fontSize: 13)),
                      onChanged: (v) => setStateDialog(() => alsoBlock = v ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await SocialService.reportMessage(
                        chatId: widget.chatId,
                        messageId: doc.id,
                        reportedUserId: reportedUserId,
                        reporterId: currentUid,
                        messageText: messageText,
                        reason: selectedReason,
                        details: detailsController.text.trim(),
                      );

                      if (alsoBlock) {
                        final targetDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(reportedUserId)
                            .get();
                        final targetData = targetDoc.data() ?? {'username': 'İsimsiz'};
                        await SocialService.blockUser(currentUid, reportedUserId, targetData);
                        if (!widget.isGroup && widget.onChatClosed != null) {
                          widget.onChatClosed!();
                        }
                      }

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(alsoBlock
                              ? 'Şikayetiniz alındı ve kullanıcı engellendi.'
                              : 'Şikayetiniz alındı, incelenecek.'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Şikayet gönderilemedi: $e')),
                      );
                    }
                  },
                  child: const Text('Şikayet Et', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessageOptions(DocumentSnapshot doc, Map<String, dynamic> data, bool isMe, String messageText) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.blueAccent),
                title: const Text('Cevapla', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingToMessage = {
                      'text': messageText,
                      'senderName': isMe ? 'Sen' : widget.chatTitle,
                    };
                    _editingMessageDoc = null;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions, color: Colors.amberAccent),
                title: const Text('Emoji Tepkisi Ekle', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showEmojiPicker(doc.id, data['reactions'] as Map<String, dynamic>?);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.orangeAccent),
                  title: const Text('Düzenle', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessageDoc = doc;
                      _messageController.text = messageText;
                      _replyingToMessage = null;
                    });
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmAndDeleteMessage(doc.id, data['senderId']);
                  },
                ),
              if (!isMe)
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.redAccent),
                  title: const Text('Şikayet Et', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(doc, data, messageText);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        InkWell(
          onTap: widget.isGroup ? _showGroupDetailsDialog : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1F1F1F),
            child: Row(
              children: [
                Icon(widget.isGroup ? Icons.group : Icons.tag, color: widget.isGroup ? Colors.blueAccent : Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.chatTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isGroup)
                  const Row(
                    children: [
                      Text('Üyeler', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
                      SizedBox(width: 4),
                      Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
              }

              var messages = snapshot.data!.docs;

              if (messages.isEmpty) {
                return const Center(
                  child: Text('Henüz mesaj yok. İlk mesajı sen gönder!', style: TextStyle(color: Colors.white54)),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  var doc = messages[index];
                  var data = doc.data() as Map<String, dynamic>;
                  bool isMe = data['senderId'] == currentUid;
                  String messageText = data['text'] ?? '';
                  String msgType = data['type'] ?? 'text';
                  bool isEdited = data['isEdited'] ?? false;
                  var replyTo = data['replyTo'] as Map<String, dynamic>?;
                  var reactions = data['reactions'] as Map<String, dynamic>? ?? {};
                  var moduleData = data['moduleData'] as Map<String, dynamic>?;
                  var itemsPayload = data['itemsPayload'] as List<dynamic>?;

                  if (msgType == 'system') {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          messageText,
                          style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return GestureDetector(
                    onLongPress: () => _showMessageOptions(doc, data, isMe, messageText),
                    child: Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          setState(() {
                            _replyingToMessage = {
                              'text': messageText,
                              'senderName': isMe ? 'Sen' : widget.chatTitle,
                            };
                            _editingMessageDoc = null;
                          });
                        } else {
                          if (isMe) {
                            setState(() {
                              _editingMessageDoc = doc;
                              _messageController.text = messageText;
                              _replyingToMessage = null;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Başkasının mesajını düzenleyemezsin!')),
                            );
                          }
                        }
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        child: const Row(
                          children: [
                            Icon(Icons.reply, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Cevapla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.orangeAccent.withValues(alpha: 0.3),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Düzenle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.edit, color: Colors.white),
                          ],
                        ),
                      ),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blueAccent : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (replyTo != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            margin: const EdgeInsets.only(bottom: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              border: Border(left: BorderSide(color: isMe ? Colors.white : Colors.blueAccent, width: 3)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  replyTo['senderName'] ?? '',
                                                  style: TextStyle(
                                                    color: isMe ? Colors.white70 : Colors.blueAccent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  replyTo['text'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        Text(
                                          messageText,
                                          style: const TextStyle(color: Colors.white, fontSize: 15),
                                        ),
                                        if (msgType == 'module_share' && moduleData != null && itemsPayload != null) ...[
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white24,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(140, 32),
                                            ),
                                            icon: const Icon(Icons.download, size: 16),
                                            label: const Text('Seçerek Kaydet', style: TextStyle(fontSize: 12)),
                                            onPressed: () => _showSaveSelectionDialog(moduleData, itemsPayload),
                                          ),
                                        ],
                                        if (isEdited)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Text('(düzenlendi)', style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert, color: Colors.white54, size: 16),
                                      color: const Color(0xFF1E1E1E),
                                      onSelected: (value) {
                                        if (value == 'reply') {
                                          setState(() {
                                            _replyingToMessage = {
                                              'text': messageText,
                                              'senderName': isMe ? 'Sen' : widget.chatTitle,
                                            };
                                            _editingMessageDoc = null;
                                          });
                                        } else if (value == 'react') {
                                          _showEmojiPicker(doc.id, reactions);
                                        } else if (value == 'edit') {
                                          if (isMe) {
                                            setState(() {
                                              _editingMessageDoc = doc;
                                              _messageController.text = messageText;
                                              _replyingToMessage = null;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Başkasının mesajını düzenleyemezsin!')),
                                            );
                                          }
                                        } else if (value == 'delete') {
                                          _confirmAndDeleteMessage(doc.id, data['senderId']);
                                        } else if (value == 'report') {
                                          _showReportDialog(doc, data, messageText);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'reply',
                                          child: Text('Cevapla', style: TextStyle(color: Colors.white, fontSize: 13)),
                                        ),
                                        const PopupMenuItem(
                                          value: 'react',
                                          child: Text('Tepki Ekle', style: TextStyle(color: Colors.white, fontSize: 13)),
                                        ),
                                        if (isMe)
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Düzenle', style: TextStyle(color: Colors.white, fontSize: 13)),
                                          ),
                                        if (isMe)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Sil', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                          ),
                                        if (!isMe)
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Text('Şikayet Et', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (reactions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Wrap(
                                  spacing: 4,
                                  children: reactions.entries.map((entry) {
                                    String emoji = entry.key;
                                    List users = entry.value as List;
                                    bool hasReacted = users.contains(currentUid);

                                    return GestureDetector(
                                      onTap: () => _toggleReaction(doc.id, emoji, reactions),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: hasReacted ? Colors.blueAccent.withValues(alpha: 0.3) : const Color(0xFF1E1E1E),
                                          border: Border.all(color: hasReacted ? Colors.blueAccent : Colors.white24, width: 1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(emoji, style: const TextStyle(fontSize: 12)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${users.length}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_replyingToMessage != null || _editingMessageDoc != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                Icon(
                  _editingMessageDoc != null ? Icons.edit : Icons.reply,
                  color: _editingMessageDoc != null ? Colors.orangeAccent : Colors.blueAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _editingMessageDoc != null ? 'Mesaj Düzenleniyor' : '${_replyingToMessage!['senderName']} kişisine yanıt veriliyor',
                        style: TextStyle(
                          color: _editingMessageDoc != null ? Colors.orangeAccent : Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _editingMessageDoc != null ? (_editingMessageDoc!.data() as Map<String, dynamic>)['text'] ?? '' : _replyingToMessage!['text'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: () {
                    setState(() {
                      _replyingToMessage = null;
                      _editingMessageDoc = null;
                      _messageController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: 10,
            bottom: 10 + MediaQuery.of(context).padding.bottom,
          ),
          color: const Color(0xFF1F1F1F),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.amberAccent, size: 26),
                onPressed: _showInlineEmojiPicker,
                tooltip: 'Emoji Ekle',
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _editingMessageDoc != null ? 'Mesajı düzenle...' : 'Mesaj gönder...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _editingMessageDoc != null ? Colors.orangeAccent : Colors.blueAccent,
                child: IconButton(
                  icon: Icon(_editingMessageDoc != null ? Icons.check : Icons.send, color: Colors.white, size: 18),
                  onPressed: () => _sendMessage(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}