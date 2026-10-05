import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedCategory = 'focus'; // 'focus', 'coins', 'bamboo'
  
  static List<Map<String, dynamic>> _cachedLeaderboardData = [];
  static DateTime? _lastFetchTime;

  List<Map<String, dynamic>> _leaderboardData = [];
  bool _isLoading = true;
  bool _isPrivateProfile = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Set<String> _myFriendUids = {};
  Set<String> _mySentRequestUids = {};

  @override
  void initState() {
    super.initState();
    
    if (_cachedLeaderboardData.isNotEmpty && _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
      _leaderboardData = List.from(_cachedLeaderboardData);
      _isLoading = false;
      _loadUserRelations();
    } else {
      _fetchLeaderboardData();
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _sortAndApplyCategory();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRelations() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users_data').doc(currentUser.uid).get(),
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('friends').get(),
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('sent_requests').get(),
      ]);

      if (!mounted) return;
      setState(() {
        final privacyDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
        _isPrivateProfile = privacyDoc.data()?['is_private_profile'] ?? false;

        _myFriendUids = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs.map((d) => d.id).toSet();
        _mySentRequestUids = (results[2] as QuerySnapshot<Map<String, dynamic>>).docs.map((d) => d.id).toSet();
        _isLoading = false;
      });
    } catch (_) {}
  }

  Future<void> _fetchLeaderboardData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      Future<DocumentSnapshot<Map<String, dynamic>>>? myPrivacyFuture;
      Future<QuerySnapshot<Map<String, dynamic>>>? myFriendsFuture;
      Future<QuerySnapshot<Map<String, dynamic>>>? mySentFuture;

      if (currentUser != null) {
        myPrivacyFuture = FirebaseFirestore.instance.collection('users_data').doc(currentUser.uid).get();
        myFriendsFuture = FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('friends').get();
        mySentFuture = FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('sent_requests').get();
      }

      final statsSnapshotFuture = FirebaseFirestore.instance.collection('users_data').get();

      final results = await Future.wait([
        statsSnapshotFuture,
        ?myPrivacyFuture,
        ?myFriendsFuture,
        ?mySentFuture,
      ]);

      final statsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;

      if (currentUser != null) {
        final myPrivacyDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
        _isPrivateProfile = myPrivacyDoc.data()?['is_private_profile'] ?? false;

        final myFriendsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
        _myFriendUids = myFriendsSnap.docs.map((d) => d.id).toSet();

        final mySentSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
        _mySentRequestUids = mySentSnap.docs.map((d) => d.id).toSet();
      }

      List<Map<String, dynamic>> rawStats = [];
      for (var doc in statsSnapshot.docs) {
        final data = doc.data();
        final uid = doc.id;

        int focusMins = (data['bamboo_focus_minutes'] ?? 0) as int;
        int coins = (data['bamboo_coins'] ?? 0) as int;

        double totalBambooHeight = 0.0;
        if (data['bamboo_heights_list'] != null) {
          try {
            List<dynamic> decoded = data['bamboo_heights_list'] is String
                ? (jsonDecode(data['bamboo_heights_list']) as List)
                : data['bamboo_heights_list'];
            for (var h in decoded) {
              totalBambooHeight += (h as num).toDouble();
            }
          } catch (_) {}
        } else if (data['bamboo_height'] != null) {
          totalBambooHeight = (data['bamboo_height'] as num).toDouble();
        }

        if (focusMins <= 0 && coins <= 0 && totalBambooHeight <= 0) {
          continue;
        }

        bool isPrivate = data['is_private_profile'] ?? false;

        rawStats.add({
          'uid': uid,
          'focus': focusMins,
          'coins': coins,
          'bamboo': totalBambooHeight.toInt(),
          'isPrivate': isPrivate,
        });
      }

      final uids = rawStats.map((e) => e['uid'] as String).toList();
      Map<String, String> uidToName = {};

      List<Future<void>> nameFutures = [];
      for (int i = 0; i < uids.length; i += 10) {
        final chunk = uids.sublist(i, (i + 10 > uids.length) ? uids.length : i + 10);
        if (chunk.isEmpty) continue;
        nameFutures.add(
          FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get()
              .then((qs) {
            for (var d in qs.docs) {
              uidToName[d.id] = (d.data())['username'] ?? '';
            }
          }),
        );
      }
      await Future.wait(nameFutures);

      List<Map<String, dynamic>> usersList = [];
      for (var stat in rawStats) {
        final uid = stat['uid'] as String;
        bool isPrivate = stat['isPrivate'] as bool;

        String displayName = uidToName[uid] ?? '';
        if (displayName.isEmpty && currentUser != null && uid == currentUser.uid && currentUser.email != null) {
          displayName = currentUser.email!.split('@')[0];
        }
        if (displayName.isEmpty) {
          displayName = 'Bamboo Şampiyonu';
        }

        if (isPrivate && uid != currentUser?.uid) {
          displayName = 'Gizli Kullanıcı 🥷';
        }

        usersList.add({
          'uid': uid,
          'name': displayName,
          'focus': stat['focus'],
          'coins': stat['coins'],
          'bamboo': stat['bamboo'],
          'isPrivate': isPrivate,
        });
      }

      _cachedLeaderboardData = usersList;
      _lastFetchTime = DateTime.now();
      _sortAndApplyCategory();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("⚠️ Liderlik tablosu yüklenemedi: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _sortAndApplyCategory() {
    List<Map<String, dynamic>> sortedList = List.from(_cachedLeaderboardData);
    
    sortedList.sort((a, b) {
      if (_selectedCategory == 'focus') {
        return b['focus'].compareTo(a['focus']);
      } else if (_selectedCategory == 'coins') {
        return b['coins'].compareTo(a['coins']);
      } else {
        return b['bamboo'].compareTo(a['bamboo']);
      }
    });

    if (_searchQuery.isNotEmpty) {
      sortedList = sortedList.where((user) {
        final name = (user['name'] as String).toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    }

    if (!mounted) return;
    setState(() {
      _leaderboardData = sortedList;
    });
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() => _isPrivateProfile = value);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users_data').doc(currentUser.uid).set({
        'is_private_profile': value,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Profilin gizlendi!' : 'Profilin herkese açık hale getirildi.'),
          backgroundColor: Colors.cyanAccent,
        ),
      );
      _cachedLeaderboardData.clear();
      _fetchLeaderboardData();
    }
  }

  Future<void> _sendFriendRequest(String targetUid, String targetName, bool targetIsPrivate) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == targetUid) return;

    if (targetIsPrivate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kullanıcı profilini gizlemiş! 🔒'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_myFriendUids.contains(targetUid) || _mySentRequestUids.contains(targetUid)) return;

    try {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final myData = myDoc.data() ?? {};

      final targetDoc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
      final targetData = targetDoc.data() ?? {};

      final batch = FirebaseFirestore.instance.batch();

      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('friend_requests')
          .doc(currentUser.uid);
      batch.set(requestRef, {
        'username': myData['username'] ?? 'İsimsiz',
        'field': myData['field'] ?? 'SAY',
        'targetRank': myData['targetRank'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final sentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('sent_requests')
          .doc(targetUid);
      batch.set(sentRef, {
        'username': targetData['username'] ?? targetName,
        'field': targetData['field'] ?? 'SAY',
        'targetRank': targetData['targetRank'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _mySentRequestUids.add(targetUid);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetName kişisine istek gönderildi! 🤝'), backgroundColor: Colors.greenAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İstek gönderilemedi: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  String _formatFocus(int mins) {
    if (mins < 60) return '$mins dk';
    int h = mins ~/ 60;
    int m = mins % 60;
    return m == 0 ? '$h sa' : '$h sa ${m}dk';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Şampiyonlar Liderlik Tablosu'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                  const Text('Gizli Profil', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(width: 4),
                  Switch(
                    value: _isPrivateProfile,
                    activeThumbColor: Colors.cyanAccent,
                    onChanged: _togglePrivacy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: const Color(0xFF181818),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCategoryButton('Odak Süresi', 'focus', Icons.timer, Colors.deepOrangeAccent),
                _buildCategoryButton('Servet (Coin)', 'coins', Icons.monetization_on, Colors.amberAccent),
                _buildCategoryButton('Toplam Boy', 'bamboo', Icons.forest, Colors.greenAccent),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Şampiyon ara...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.greenAccent),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : _leaderboardData.isEmpty
                    ? const Center(child: Text('Aradığın kriterde şampiyon bulunamadı.', style: TextStyle(color: Colors.white54)))
                    : RefreshIndicator(
                        color: Colors.greenAccent,
                        backgroundColor: const Color(0xFF1E1E1E),
                        onRefresh: () async {
                          _cachedLeaderboardData.clear();
                          await _fetchLeaderboardData();
                        },
                        child: ListView.builder(
                          itemCount: _leaderboardData.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemBuilder: (context, index) {
                            final user = _leaderboardData[index];
                            bool isMe = user['uid'] == currentUserUid;
                            
                            int actualRank = _cachedLeaderboardData.indexWhere((u) => u['uid'] == user['uid']) + 1;

                            Color rankColor = Colors.white54;
                            if (actualRank == 1) rankColor = Colors.amberAccent;
                            if (actualRank == 2) rankColor = Colors.white70;
                            if (actualRank == 3) rankColor = Colors.brown;

                            String statText = '';
                            if (_selectedCategory == 'focus') statText = _formatFocus(user['focus']);
                            if (_selectedCategory == 'coins') statText = '${user['coins']} 🪙';
                            if (_selectedCategory == 'bamboo') statText = '${user['bamboo']} cm 🎋';

                            bool isAlreadyFriend = _myFriendUids.contains(user['uid']);
                            bool requestSent = _mySentRequestUids.contains(user['uid']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF1E2E1E) : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isMe ? Colors.greenAccent : (actualRank <= 3 ? rankColor.withValues(alpha: 0.5) : Colors.white12),
                                  width: isMe ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 36,
                                    child: Center(
                                      child: actualRank <= 3
                                          ? Text(
                                              actualRank == 1 ? '🥇' : (actualRank == 2 ? '🥈' : '🥉'),
                                              style: const TextStyle(fontSize: 22),
                                            )
                                          : Text(
                                              '#$actualRank',
                                              style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isMe ? '${user['name']} (Sen)' : user['name'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isMe ? Colors.greenAccent : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedCategory == 'focus' ? 'Toplam Odaklanma' : (_selectedCategory == 'coins' ? 'Toplam Servet' : 'Toplam Orman Uzunluğu'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  
                                  Text(
                                    statText,
                                    style: TextStyle(
                                      color: _selectedCategory == 'coins' ? Colors.amberAccent : (_selectedCategory == 'bamboo' ? Colors.greenAccent : Colors.deepOrangeAccent),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  
                                  if (!isMe)
                                    isAlreadyFriend
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.greenAccent),
                                            ),
                                            child: const Text('Arkadaş 🤝', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        : requestSent
                                            ? const Text('İstek Atıldı ⏳', style: TextStyle(color: Colors.amberAccent, fontSize: 10))
                                            : user['isPrivate']
                                                ? const Text('Gizli 🔒', style: TextStyle(color: Colors.white54, fontSize: 10))
                                                : IconButton(
                                                    icon: const Icon(Icons.person_add_rounded, color: Colors.cyanAccent, size: 20),
                                                    tooltip: 'Arkadaş Ekle',
                                                    onPressed: () => _sendFriendRequest(user['uid'], user['name'], user['isPrivate']),
                                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String title, String categoryKey, IconData icon, Color color) {
    bool isSelected = _selectedCategory == categoryKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = categoryKey;
          });
          _sortAndApplyCategory();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.white54, size: 15),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
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