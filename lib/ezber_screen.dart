import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'user_data_service.dart';

// --- VERİ MODELLERİ ---

class EzberCardItem {
  String question;
  String answer;
  int score; // -10 ile +10 arası

  EzberCardItem({required this.question, required this.answer, this.score = 0});

  Map<String, dynamic> toJson() => {'q': question, 'a': answer, 's': score};
  factory EzberCardItem.fromJson(Map<String, dynamic> json) {
    int parsedScore = 0;
    if (json['s'] != null) {
      if (json['s'] is num) {
        parsedScore = (json['s'] as num).toInt();
      } else if (json['s'] is String) {
        parsedScore = int.tryParse(json['s']) ?? 0;
      }
    }
    return EzberCardItem(
      question: json['q'] ?? '',
      answer: json['a'] ?? '',
      score: parsedScore,
    );
  }
}

class EzberDeck {
  String title;
  List<EzberCardItem> cards;

  EzberDeck({required this.title, required this.cards});

  Map<String, dynamic> toJson() => {
        'title': title,
        'cards': cards.map((c) => c.toJson()).toList(),
      };
  factory EzberDeck.fromJson(Map<String, dynamic> json) {
    var list = json['cards'] as List? ?? [];
    return EzberDeck(
      title: json['title'] ?? '',
      cards: list.map((i) => EzberCardItem.fromJson(i)).toList(),
    );
  }
}

class EzberUnit {
  String title;
  List<EzberDeck> decks;

  EzberUnit({required this.title, required this.decks});

  Map<String, dynamic> toJson() => {
        'title': title,
        'decks': decks.map((d) => d.toJson()).toList(),
      };
  factory EzberUnit.fromJson(Map<String, dynamic> json) {
    var list = json['decks'] as List? ?? [];
    return EzberUnit(
      title: json['title'] ?? '',
      decks: list.map((i) => EzberDeck.fromJson(i)).toList(),
    );
  }
}

class EzberSubject {
  String title;
  List<EzberUnit> units;

  EzberSubject({required this.title, required this.units});

  Map<String, dynamic> toJson() => {
        'title': title,
        'units': units.map((u) => u.toJson()).toList(),
      };
  factory EzberSubject.fromJson(Map<String, dynamic> json) {
    var list = json['units'] as List? ?? [];
    return EzberSubject(
      title: json['title'] ?? '',
      units: list.map((i) => EzberUnit.fromJson(i)).toList(),
    );
  }
}

class EzberDataManager {
  static List<EzberSubject> subjects = [];

  static Future<String> _getUserKey() async {
    try {
      final allData = await UserDataService.fetchAllData();
      String userEmail = allData['current_user_email'] ?? 'default_user';
      return 'ezber_subjects_$userEmail';
    } catch (e) {
      return 'ezber_subjects_default';
    }
  }

  static Future<void> loadData() async {
    try {
      final allData = await UserDataService.fetchAllData();
      final String key = await _getUserKey();
      final String? dataStr = allData[key];
      if (dataStr != null && dataStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(dataStr);
        subjects = decoded.map((s) => EzberSubject.fromJson(s)).toList();
      } else {
        subjects = [];
      }
    } catch (e) {
      subjects = [];
    }
  }

  static Future<void> saveData() async {
    final String encoded = jsonEncode(subjects.map((s) => s.toJson()).toList());
    final String key = await _getUserKey();
    await UserDataService.saveModuleData(key, encoded);
  }
}

// --- 1. DERSLER EKRANI (KÖK EKRAN) ---

class EzberScreen extends StatefulWidget {
  const EzberScreen({super.key});

  @override
  State<EzberScreen> createState() => _EzberScreenState();
}

class _EzberScreenState extends State<EzberScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await EzberDataManager.loadData();
    setState(() => _isLoading = false);
  }

  void _showNewSubjectDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.deepPurple.shade900,
          title: const Text('Yeni Ders Ekle', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ders adı (Örn: Edebiyat, Biyoloji)',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    EzberDataManager.subjects.add(EzberSubject(title: controller.text.trim(), units: []));
                    EzberDataManager.saveData();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Oluştur', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSubject(EzberSubject subject) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Dersi Sil', style: TextStyle(color: Colors.white)),
          content: Text('"${subject.title}" dersini ve içindeki tüm ünite, deste ve kartları silmek istediğine emin misin?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                setState(() {
                  EzberDataManager.subjects.remove(subject);
                  EzberDataManager.saveData();
                });
                Navigator.pop(context);
              },
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _openTestSetup() {
    if (EzberDataManager.subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test çözmek için önce ders ve içerik eklemelisin!')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TestSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Ezber - Dersler'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.deepPurple,
              elevation: 0,
            ),
            onPressed: _openTestSetup,
            icon: const Icon(Icons.quiz),
            label: const Text('TEST OL', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: EzberDataManager.subjects.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books, size: 64, color: Colors.white54),
                  SizedBox(height: 16),
                  Text('Henüz bir ders eklenmedi.\nSağ alttan ilk dersini ekle!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: EzberDataManager.subjects.length,
              itemBuilder: (context, index) {
                final subject = EzberDataManager.subjects[index];
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.deepPurpleAccent.withValues(alpha: 0.3))),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: const Icon(Icons.book, color: Colors.deepPurpleAccent, size: 36),
                    title: Text(subject.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    subtitle: Text('${subject.units.length} Ünite', style: const TextStyle(color: Colors.white60)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                          onPressed: () => _confirmDeleteSubject(subject),
                          tooltip: 'Dersi Sil',
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepPurpleAccent),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EzberUnitScreen(subject: subject)),
                      ).then((_) => setState(() {}));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewSubjectDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ders Ekle', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- 2. ÜNİTELER EKRANI ---

class EzberUnitScreen extends StatefulWidget {
  final EzberSubject subject;
  const EzberUnitScreen({super.key, required this.subject});

  @override
  State<EzberUnitScreen> createState() => _EzberUnitScreenState();
}

class _EzberUnitScreenState extends State<EzberUnitScreen> {
  void _showNewUnitDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.deepPurple.shade900,
          title: const Text('Yeni Ünite Oluştur', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ünite adı (Örn: 1. Ünite - Milli Edebiyat)',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    widget.subject.units.add(EzberUnit(title: controller.text.trim(), decks: []));
                    EzberDataManager.saveData();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Oluştur', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteUnit(EzberUnit unit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Üniteyi Sil', style: TextStyle(color: Colors.white)),
          content: Text('"${unit.title}" ünitesini ve içindeki tüm deste ve kartları silmek istediğine emin misin?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.subject.units.remove(unit);
                  EzberDataManager.saveData();
                });
                Navigator.pop(context);
              },
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.subject.title),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: widget.subject.units.isEmpty
          ? const Center(child: Text('Bu derste henüz ünite yok.', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.subject.units.length,
              itemBuilder: (context, index) {
                final unit = widget.subject.units[index];
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: const Icon(Icons.folder_special, color: Colors.deepPurpleAccent, size: 36),
                    title: Text(unit.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    subtitle: Text('${unit.decks.length} Deste', style: const TextStyle(color: Colors.white60)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                          onPressed: () => _confirmDeleteUnit(unit),
                          tooltip: 'Üniteyi Sil',
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepPurpleAccent),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EzberDeckScreen(unit: unit)),
                      ).then((_) => setState(() {}));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewUnitDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ünite Ekle', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- 3. DESTELER EKRANI ---

class EzberDeckScreen extends StatefulWidget {
  final EzberUnit unit;
  const EzberDeckScreen({super.key, required this.unit});

  @override
  State<EzberDeckScreen> createState() => _EzberDeckScreenState();
}

class _EzberDeckScreenState extends State<EzberDeckScreen> {
  void _showNewDeckDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.deepPurple.shade900,
          title: const Text('Yeni Deste Oluştur', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Deste adı (Örn: Tanzimat Sanatçıları)',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    widget.unit.decks.add(EzberDeck(title: controller.text.trim(), cards: []));
                    EzberDataManager.saveData();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Oluştur', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteDeck(EzberDeck deck) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Desteyi Sil', style: TextStyle(color: Colors.white)),
          content: Text('"${deck.title}" destesini ve içindeki tüm kartları silmek istediğine emin misin?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.unit.decks.remove(deck);
                  EzberDataManager.saveData();
                });
                Navigator.pop(context);
              },
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.unit.title),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: widget.unit.decks.isEmpty
          ? const Center(child: Text('Bu ünitede henüz deste yok.', style: TextStyle(color: Colors.white54)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: widget.unit.decks.length,
              itemBuilder: (context, index) {
                final deck = widget.unit.decks[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EzberStudyScreen(deck: deck)),
                    ).then((_) => setState(() {}));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                      border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.5), width: 2),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.style_rounded, color: Colors.deepPurpleAccent, size: 28),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDeleteDeck(deck),
                              tooltip: 'Desteyi Sil',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(deck.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${deck.cards.length} Kart', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewDeckDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Deste Ekle', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- 4. KART OLUŞTURMA EKRANI (SINGLECHILDSCROLLVIEW EKLENDİ) ---

class EzberCardEditScreen extends StatefulWidget {
  final EzberDeck deck;
  const EzberCardEditScreen({super.key, required this.deck});

  @override
  State<EzberCardEditScreen> createState() => _EzberCardEditScreenState();
}

class _EzberCardEditScreenState extends State<EzberCardEditScreen> {
  final TextEditingController _qController = TextEditingController();
  final TextEditingController _aController = TextEditingController();

  void _saveCard() {
    if (_qController.text.trim().isEmpty || _aController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Soru ve cevap boş olamaz!')));
      return;
    }
    widget.deck.cards.add(EzberCardItem(question: _qController.text.trim(), answer: _aController.text.trim()));
    EzberDataManager.saveData();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Yeni Flashcard Ekle'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _qController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Soru / Kavram (Örn: Cumhuriyet kaç yılında ilan edildi?)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Cevap / Açıklama (Örn: 1923)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveCard,
                icon: const Icon(Icons.check),
                label: const Text('Kartı Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 5. KART ÇALIŞMA (FLIP) VE PUANLAMA EKRANI ---

class EzberStudyScreen extends StatefulWidget {
  final EzberDeck deck;
  const EzberStudyScreen({super.key, required this.deck});

  @override
  State<EzberStudyScreen> createState() => _EzberStudyScreenState();
}

class _EzberStudyScreenState extends State<EzberStudyScreen> {
  late List<EzberCardItem> _sessionCards;
  int _currentIndex = 0;
  bool _isShowingAnswer = false;

  @override
  void initState() {
    super.initState();
    _sessionCards = List.from(widget.deck.cards);
  }

  @override
  void dispose() {
    EzberDataManager.saveData(); 
    super.dispose();
  }

  Color _getScoreColor(int score) {
    if (score == 0) return Colors.grey.shade600;
    if (score > 0) return Color.lerp(Colors.grey.shade600, Colors.green.shade500, score / 10.0)!;
    return Color.lerp(Colors.grey.shade600, Colors.red.shade500, score.abs() / 10.0)!;
  }

  void _shuffleRemainingCards() {
    if (_sessionCards.length - _currentIndex > 1) {
      setState(() {
        var sublist = _sessionCards.sublist(_currentIndex);
        sublist.shuffle();
        _sessionCards.setRange(_currentIndex, _sessionCards.length, sublist);
        _isShowingAnswer = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Açık olan ve kalan kartlar karıştırıldı!'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _showFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.deepPurpleAccent.withValues(alpha: 0.5))),
          title: const Text('Tebrikler!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: const Text('Bu destedeki tüm flashcard kartlarını bitirdiniz!', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Çık', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentIndex = 0;
                  _sessionCards = List.from(widget.deck.cards);
                  _isShowingAnswer = false;
                });
              },
              child: const Text('Yeniden Başla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCurrentCard() {
    if (_sessionCards.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Kartı Sil', style: TextStyle(color: Colors.white)),
          content: const Text('Bu kartı silmek istediğine emin misin?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  final cardToDelete = _sessionCards[_currentIndex];
                  _sessionCards.removeAt(_currentIndex);
                  widget.deck.cards.remove(cardToDelete);
                  EzberDataManager.saveData();
                  
                  if (_sessionCards.isEmpty) {
                    _isShowingAnswer = false;
                  } else if (_currentIndex >= _sessionCards.length) {
                    _currentIndex = 0;
                    _isShowingAnswer = false;
                    _showFinishedDialog();
                  } else {
                    _isShowingAnswer = false;
                  }
                });
              },
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _handleScore(int modifier) {
    if (_sessionCards.isEmpty) return;
    
    final card = _sessionCards[_currentIndex];
    card.score = (card.score + modifier).clamp(-10, 10);
    EzberDataManager.saveData();
    
    if (_currentIndex < _sessionCards.length - 1) {
      setState(() {
        _isShowingAnswer = false;
        _currentIndex++;
      });
    } else {
      setState(() {
        _isShowingAnswer = false;
      });
      _showFinishedDialog();
    }
  }

  Widget _buildCardContent(bool isAnswer, EzberCardItem currentCard) {
    return Container(
      width: double.infinity,
      height: 350,
      decoration: BoxDecoration(
        color: isAnswer ? const Color(0xFF251F36) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.deepPurpleAccent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getScoreColor(currentCard.score),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentCard.score > 0 ? '+' : ''}${currentCard.score}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isAnswer ? 'CEVAP' : 'SORU',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAnswer ? Colors.deepPurpleAccent : Colors.pinkAccent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAnswer ? currentCard.answer : currentCard.question,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: Text('(Çevirmek için dokun)', style: TextStyle(fontSize: 11, color: Colors.white54))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.deck.title),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, color: Colors.amber),
            onPressed: _shuffleRemainingCards,
            tooltip: 'Açık olan ve kalan kartları karıştır',
          ),
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: Colors.deepPurpleAccent),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => EzberCardEditScreen(deck: widget.deck)));
              setState(() {
                _sessionCards = List.from(widget.deck.cards);
              });
            },
            tooltip: 'Kart Ekle',
          ),
        ],
      ),
      body: _sessionCards.isEmpty
          ? Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => EzberCardEditScreen(deck: widget.deck)));
                  setState(() {
                    _sessionCards = List.from(widget.deck.cards);
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('İlk Kartı Ekle', style: TextStyle(color: Colors.white)),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Text('Kart ${_currentIndex + 1} / ${_sessionCards.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                        onPressed: _confirmDeleteCurrentCard,
                        tooltip: 'Kartı Sil',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => setState(() => _isShowingAnswer = !_isShowingAnswer),
                    child: TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: _isShowingAnswer ? 1 : 0),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, double val, child) {
                        bool isBack = val >= 0.5;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(val * pi),
                          child: isBack
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(pi),
                                  child: _buildCardContent(true, _sessionCards[_currentIndex]),
                                )
                              : _buildCardContent(false, _sessionCards[_currentIndex]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () => _handleScore(-1),
                        child: Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.3), shape: BoxShape.circle, border: Border.all(color: Colors.redAccent, width: 2)),
                          child: const Icon(Icons.close, color: Colors.redAccent, size: 36),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _handleScore(1),
                        child: Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(color: Colors.green.shade900.withValues(alpha: 0.3), shape: BoxShape.circle, border: Border.all(color: Colors.greenAccent, width: 2)),
                          child: const Icon(Icons.check, color: Colors.greenAccent, size: 36),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

// --- 6. TEST AYARLARI EKRANI ---

class TestSetupScreen extends StatefulWidget {
  const TestSetupScreen({super.key});

  @override
  State<TestSetupScreen> createState() => _TestSetupScreenState();
}

class _TestSetupScreenState extends State<TestSetupScreen> {
  final Set<EzberSubject> _selectedSubjects = {};
  final Set<EzberUnit> _selectedUnits = {};
  final Set<EzberDeck> _selectedDecks = {};
  final TextEditingController _countController = TextEditingController(text: '10');

  List<EzberUnit> get _availableUnits {
    List<EzberUnit> units = [];
    for (var subject in _selectedSubjects) {
      units.addAll(subject.units);
    }
    return units;
  }

  List<EzberDeck> get _availableDecks {
    List<EzberDeck> decks = [];
    for (var unit in _selectedUnits) {
      decks.addAll(unit.decks);
    }
    return decks;
  }

  void _startTest() {
    if (_selectedDecks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen en az bir deste seçin!')));
      return;
    }
    int count = int.tryParse(_countController.text) ?? 10;
    
    int totalAvailableCards = _selectedDecks.fold(0, (sum, deck) => sum + deck.cards.length);
    if (totalAvailableCards == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçtiğiniz destelerde hiç kart yok!')));
      return;
    }

    if (count > totalAvailableCards) count = totalAvailableCards;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TestActiveScreen(selectedDecks: _selectedDecks.toList(), questionCount: count)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Test Ayarları'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Ders Seçimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
              child: Column(
                children: EzberDataManager.subjects.map((subject) {
                  return CheckboxListTile(
                    title: Text(subject.title, style: const TextStyle(color: Colors.white)),
                    value: _selectedSubjects.contains(subject),
                    activeColor: Colors.deepPurple,
                    checkColor: Colors.white,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedSubjects.add(subject);
                        } else {
                          _selectedSubjects.remove(subject);
                          _selectedUnits.removeAll(subject.units);
                          for (var unit in subject.units) {
                            _selectedDecks.removeAll(unit.decks);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            
            if (_selectedSubjects.isNotEmpty) ...[
              const Text('2. Ünite Seçimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                child: Column(
                  children: _availableUnits.map((unit) {
                    return CheckboxListTile(
                      title: Text(unit.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${unit.decks.length} Deste', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                      value: _selectedUnits.contains(unit),
                      activeColor: Colors.deepPurple,
                      checkColor: Colors.white,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUnits.add(unit);
                          } else {
                            _selectedUnits.remove(unit);
                            _selectedDecks.removeAll(unit.decks);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_selectedUnits.isNotEmpty) ...[
              const Text('3. Deste (Konu) Seçimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                child: Column(
                  children: _availableDecks.map((deck) {
                    return CheckboxListTile(
                      title: Text(deck.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${deck.cards.length} Kart', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                      value: _selectedDecks.contains(deck),
                      activeColor: Colors.deepPurple,
                      checkColor: Colors.white,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedDecks.add(deck);
                          } else {
                            _selectedDecks.remove(deck);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_selectedDecks.isNotEmpty) ...[
              const Text('4. Soru Sayısı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
              const SizedBox(height: 10),
              TextField(
                controller: _countController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _startTest,
                  child: const Text('TESTE BAŞLA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- 7. AKTİF TEST EKRANI ---

class TestQuestionData {
  final EzberCardItem card;
  final EzberDeck parentDeck;
  TestQuestionData(this.card, this.parentDeck);
}

class TestActiveScreen extends StatefulWidget {
  final List<EzberDeck> selectedDecks;
  final int questionCount;

  const TestActiveScreen({super.key, required this.selectedDecks, required this.questionCount});

  @override
  State<TestActiveScreen> createState() => _TestActiveScreenState();
}

class _TestActiveScreenState extends State<TestActiveScreen> {
  List<TestQuestionData> _questions = [];
  int _currentIndex = 0;
  int _correctAnswers = 0;
  
  List<String> _currentOptions = [];
  String? _selectedOption;
  bool _isAnswerChecked = false;

  @override
  void dispose() {
    EzberDataManager.saveData();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _generateQuestions();
    if (_questions.isNotEmpty) {
      _generateOptionsForCurrent();
    }
  }

  void _generateQuestions() {
    List<TestQuestionData> pool = [];
    for (var deck in widget.selectedDecks) {
      for (var card in deck.cards) {
        pool.add(TestQuestionData(card, deck));
      }
    }

    List<TestQuestionData> selected = [];
    Random rand = Random();
    
    int needed = widget.questionCount;
    if (needed > pool.length) needed = pool.length;

    for (int i = 0; i < needed; i++) {
      double totalWeight = 0;
      List<double> cumulativeWeights = [];
      
      for (var item in pool) {
        double weight = (15 - item.card.score).toDouble(); 
        totalWeight += weight;
        cumulativeWeights.add(totalWeight);
      }

      double r = rand.nextDouble() * totalWeight;
      int selectedIndex = 0;
      for (int j = 0; j < cumulativeWeights.length; j++) {
        if (r <= cumulativeWeights[j]) {
          selectedIndex = j;
          break;
        }
      }

      selected.add(pool[selectedIndex]);
      pool.removeAt(selectedIndex);
    }

    _questions = selected;
  }

  void _generateOptionsForCurrent() {
    final currentQ = _questions[_currentIndex];
    
    List<String> distractors = currentQ.parentDeck.cards
        .where((c) => c != currentQ.card)
        .map((c) => c.answer)
        .toList();
    
    distractors.shuffle();
    
    _currentOptions = [currentQ.card.answer];
    _currentOptions.addAll(distractors.take(3));
    
    _currentOptions.shuffle();
    _selectedOption = null;
    _isAnswerChecked = false;
  }

  void _checkAnswer(String option) {
    if (_isAnswerChecked) return;
    
    setState(() {
      _selectedOption = option;
      _isAnswerChecked = true;
      
      final card = _questions[_currentIndex].card;
      if (option == card.answer) {
        _correctAnswers++;
        card.score = (card.score + 1).clamp(-10, 10);
      } else {
        card.score = (card.score - 1).clamp(-10, 10);
      }
    });
  }

  void _confirmDeleteTestCard() {
    if (_questions.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Kartı Sil', style: TextStyle(color: Colors.white)),
          content: const Text('Bu kartı silmek istediğine emin misin?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  final currentQ = _questions[_currentIndex];
                  currentQ.parentDeck.cards.remove(currentQ.card);
                  _questions.removeAt(_currentIndex);
                  EzberDataManager.saveData();

                  if (_questions.isEmpty) {
                    _showResultDialog();
                  } else {
                    if (_currentIndex >= _questions.length) {
                      _currentIndex = _questions.length - 1;
                    }
                    _generateOptionsForCurrent();
                  }
                });
              },
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _generateOptionsForCurrent();
      });
    } else {
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.deepPurpleAccent.withValues(alpha: 0.5))),
          title: const Text('Test Bitti!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_correctAnswers / ${_questions.length}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber)),
              const SizedBox(height: 10),
              const Text('Doğru Yanıt', style: TextStyle(color: Colors.white60)),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Derslere Dön', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
        body: const Center(child: Text('Yeterli kart bulunamadı.', style: TextStyle(color: Colors.white54))),
      );
    }

    final currentQ = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('Soru ${_currentIndex + 1} / ${_questions.length}'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _confirmDeleteTestCard,
            tooltip: 'Bu Soruyu/Kartı Sil',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Text(currentQ.parentDeck.title, style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                    currentQ.card.question,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: ListView.builder(
                itemCount: _currentOptions.length,
                itemBuilder: (context, index) {
                  final option = _currentOptions[index];
                  final isCorrectAnswer = option == currentQ.card.answer;
                  final isSelected = option == _selectedOption;

                  Color btnColor = const Color(0xFF1E1E1E);
                  Color borderColor = Colors.white24;
                  Color textColor = Colors.white;

                  if (_isAnswerChecked) {
                    if (isCorrectAnswer) {
                      btnColor = Colors.green.shade900.withValues(alpha: 0.4);
                      borderColor = Colors.greenAccent;
                      textColor = Colors.greenAccent;
                    } else if (isSelected && !isCorrectAnswer) {
                      btnColor = Colors.red.shade900.withValues(alpha: 0.4);
                      borderColor = Colors.redAccent;
                      textColor = Colors.redAccent;
                    }
                  }

                  return GestureDetector(
                    onTap: () => _checkAnswer(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: btnColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isAnswerChecked)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _nextQuestion,
                child: const Text('Sonraki Soru', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}