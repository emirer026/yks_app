import 'dart:convert';
import 'package:flutter/material.dart';
import 'user_data_service.dart';

// --- ÇİZİM ÇİZGİ MODELİ ---
class DrawingStroke {
  List<Offset> points;
  Color color;
  double strokeWidth;
  double opacity;
  bool isEraser;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.isEraser,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.toARGB32(),
        'width': strokeWidth,
        'opacity': opacity,
        'eraser': isEraser,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    var pList = json['points'] as List? ?? [];
    List<Offset> pts = pList.map((p) => Offset(p['dx']?.toDouble() ?? 0.0, p['dy']?.toDouble() ?? 0.0)).toList();
    return DrawingStroke(
      points: pts,
      color: Color(json['color'] ?? Colors.black.toARGB32()),
      strokeWidth: json['width']?.toDouble() ?? 4.0,
      opacity: json['opacity']?.toDouble() ?? 1.0,
      isEraser: json['eraser'] ?? false,
    );
  }
}

// --- METİN PARÇASI (BLOK) MODELİ ---
class TextSegment {
  String text;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  int textColorValue;

  TextSegment({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.textColorValue = 0xFF212121,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isBold': isBold,
        'isItalic': isItalic,
        'isUnderline': isUnderline,
        'isStrikethrough': isStrikethrough,
        'textColor': textColorValue,
      };

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      text: json['text'] ?? '',
      isBold: json['isBold'] ?? false,
      isItalic: json['isItalic'] ?? false,
      isUnderline: json['isUnderline'] ?? false,
      isStrikethrough: json['isStrikethrough'] ?? false,
      textColorValue: json['textColor'] ?? 0xFF212121,
    );
  }
}

// --- VERİ MODELLERİ ---
class BilgiCardItem {
  List<TextSegment> segments;
  List<DrawingStroke> strokes;
  int cardColorValue;

  BilgiCardItem({
    required this.segments,
    required this.strokes,
    this.cardColorValue = 0xFFFFFFFF,
  });

  Map<String, dynamic> toJson() => {
        'segments': segments.map((s) => s.toJson()).toList(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'cardColor': cardColorValue,
      };

  factory BilgiCardItem.fromJson(Map<String, dynamic> json) {
    var sList = json['strokes'] as List? ?? [];
    List<TextSegment> segs = [];
    if (json['segments'] != null) {
      segs = (json['segments'] as List).map((s) => TextSegment.fromJson(s)).toList();
    } else if (json['text'] != null) {
      segs = [
        TextSegment(
          text: json['text'] ?? '',
          isBold: json['isBold'] ?? false,
          isItalic: json['isItalic'] ?? false,
          isUnderline: json['isUnderline'] ?? false,
          isStrikethrough: json['isStrikethrough'] ?? false,
          textColorValue: json['textColor'] ?? 0xFF212121,
        )
      ];
    }
    return BilgiCardItem(
      segments: segs,
      strokes: sList.map((s) => DrawingStroke.fromJson(s)).toList(),
      cardColorValue: json['cardColor'] ?? 0xFFFFFFFF,
    );
  }
}

class BilgiDeck {
  String title;
  List<BilgiCardItem> cards;

  BilgiDeck({required this.title, required this.cards});

  Map<String, dynamic> toJson() => {
        'title': title,
        'cards': cards.map((c) => c.toJson()).toList(),
      };

  factory BilgiDeck.fromJson(Map<String, dynamic> json) {
    var list = json['cards'] as List? ?? [];
    return BilgiDeck(
      title: json['title'] ?? '',
      cards: list.map((i) => BilgiCardItem.fromJson(i)).toList(),
    );
  }
}

class BilgiUnit {
  String title;
  List<BilgiDeck> decks;

  BilgiUnit({required this.title, required this.decks});

  Map<String, dynamic> toJson() => {
        'title': title,
        'decks': decks.map((d) => d.toJson()).toList(),
      };

  factory BilgiUnit.fromJson(Map<String, dynamic> json) {
    var list = json['decks'] as List? ?? [];
    return BilgiUnit(
      title: json['title'] ?? '',
      decks: list.map((i) => BilgiDeck.fromJson(i)).toList(),
    );
  }
}

class BilgiSubject {
  String title;
  List<BilgiUnit> units;

  BilgiSubject({required this.title, required this.units});

  Map<String, dynamic> toJson() => {
        'title': title,
        'units': units.map((u) => u.toJson()).toList(),
      };

  factory BilgiSubject.fromJson(Map<String, dynamic> json) {
    var list = json['units'] as List? ?? [];
    return BilgiSubject(
      title: json['title'] ?? '',
      units: list.map((i) => BilgiUnit.fromJson(i)).toList(),
    );
  }
}

class BilgiDataManager {
  static List<BilgiSubject> subjects = [];

  static Future<String> _getUserKey() async {
    try {
      final allData = await UserDataService.fetchAllData();
      String userEmail = allData['current_user_email'] ?? 'default_user';
      return 'bilgi_karti_subjects_$userEmail';
    } catch (e) {
      return 'bilgi_karti_subjects_default';
    }
  }

  static Future<void> loadData() async {
    try {
      final allData = await UserDataService.fetchAllData();
      final String key = await _getUserKey();
      final String? dataStr = allData[key];
      if (dataStr != null && dataStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(dataStr);
        subjects = decoded.map((s) => BilgiSubject.fromJson(s)).toList();
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

// --- ORTAK METİN RENDER FONKSİYONU ---
Widget buildCardRichText(List<TextSegment> segments) {
  if (segments.isEmpty || segments.every((s) => s.text.trim().isEmpty)) {
    return const SizedBox.shrink();
  }
  return RichText(
    text: TextSpan(
      children: segments.map((segment) {
        TextDecoration decoration = TextDecoration.none;
        if (segment.isUnderline && segment.isStrikethrough) {
          decoration = TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
        } else if (segment.isUnderline) {
          decoration = TextDecoration.underline;
        } else if (segment.isStrikethrough) {
          decoration = TextDecoration.lineThrough;
        }

        return TextSpan(
          text: segment.text + (segments.last == segment ? '' : '\n'),
          style: TextStyle(
            color: Color(segment.textColorValue),
            fontWeight: segment.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: segment.isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: decoration,
            fontSize: 16,
          ),
        );
      }).toList(),
    ),
  );
}

// --- ORTAK KART GÖVDESİ ---
Widget buildCardBody({
  required Color cardColor,
  required List<TextSegment> segments,
  required List<DrawingStroke> strokes,
  ValueNotifier<List<DrawingStroke>>? strokesNotifier,
  bool isInteractive = false,
  Function(Offset)? onPanStart,
  Function(Offset)? onPanUpdate,
}) {
  return Container(
    width: 320,
    height: 420,
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.tealAccent, width: 2),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: strokesNotifier != null
                ? ValueListenableBuilder<List<DrawingStroke>>(
                    valueListenable: strokesNotifier,
                    builder: (context, currentStrokes, child) {
                      return CustomPaint(
                        painter: CardDrawingPainter(strokes: currentStrokes),
                        size: Size.infinite,
                      );
                    },
                  )
                : CustomPaint(
                    painter: CardDrawingPainter(strokes: strokes),
                    size: Size.infinite,
                  ),
          ),
          if (isInteractive && strokesNotifier != null)
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (onPanStart != null) onPanStart(event.localPosition);
                },
                onPointerMove: (event) {
                  if (onPanUpdate != null) onPanUpdate(event.localPosition);
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (segments.any((s) => s.text.trim().isNotEmpty))
                  Flexible(
                    child: SingleChildScrollView(
                      child: buildCardRichText(segments),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// --- 1. DERSLER EKRANI ---
class BilgiKartiScreen extends StatefulWidget {
  const BilgiKartiScreen({super.key});

  @override
  State<BilgiKartiScreen> createState() => _BilgiKartiScreenState();
}

class _BilgiKartiScreenState extends State<BilgiKartiScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await BilgiDataManager.loadData();
    setState(() => _isLoading = false);
  }

  void _showNewSubjectDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.teal.shade900,
          title: const Text('Yeni Ders Ekle', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Ders adı (Örn: Tarih)',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    BilgiDataManager.subjects.add(BilgiSubject(title: controller.text.trim(), units: []));
                    BilgiDataManager.saveData();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Oluştur', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSubject(BilgiSubject subject) {
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
                  BilgiDataManager.subjects.remove(subject);
                  BilgiDataManager.saveData();
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
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Bilgi Kartları - Dersler'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            onPressed: () {
              if (BilgiDataManager.subjects.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test çözmek için önce ders ve içerik eklemelisin!')));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BilgiTestSetupScreen()));
            },
            icon: const Icon(Icons.quiz),
            label: const Text('KARIŞTIR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BilgiDataManager.subjects.isEmpty
          ? const Center(child: Text('Henüz ders eklenmedi.', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: BilgiDataManager.subjects.length,
              itemBuilder: (context, index) {
                final subject = BilgiDataManager.subjects[index];
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3))),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: const Icon(Icons.book, color: Colors.tealAccent, size: 36),
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
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.tealAccent),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => BilgiUnitScreen(subject: subject)))
                          .then((_) => setState(() {}));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewSubjectDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ders Ekle', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- 2. ÜNİTELER EKRANI ---
class BilgiUnitScreen extends StatefulWidget {
  final BilgiSubject subject;
  const BilgiUnitScreen({super.key, required this.subject});

  @override
  State<BilgiUnitScreen> createState() => _BilgiUnitScreenState();
}

class _BilgiUnitScreenState extends State<BilgiUnitScreen> {
  void _showNewUnitDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.teal.shade900,
          title: const Text('Yeni Ünite Oluştur', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Ünite adı',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    widget.subject.units.add(BilgiUnit(title: controller.text.trim(), decks: []));
                    BilgiDataManager.saveData();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Oluştur', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteUnit(BilgiUnit unit) {
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
                  BilgiDataManager.saveData();
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
          ? const Center(child: Text('Ünite yok.', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.subject.units.length,
              itemBuilder: (context, index) {
                final unit = widget.subject.units[index];
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: const Icon(Icons.folder_special, color: Colors.tealAccent, size: 36),
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
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.tealAccent),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => BilgiDeckScreen(unit: unit)))
                          .then((_) => setState(() {}));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewUnitDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ünite Ekle', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- 3. DESTELER EKRANI ---
class BilgiDeckScreen extends StatefulWidget {
  final BilgiUnit unit;
  const BilgiDeckScreen({super.key, required this.unit});

  @override
  State<BilgiDeckScreen> createState() => _BilgiDeckScreenState();
}

class _BilgiDeckScreenState extends State<BilgiDeckScreen> {
  void _showNewDeckDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.teal.shade900,
          title: const Text('Yeni Deste Oluştur', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Deste adı (Örn: Osmanlı Kuruluş)',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    widget.unit.decks.add(BilgiDeck(title: controller.text.trim(), cards: []));
                    BilgiDataManager.saveData();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Oluştur', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteDeck(BilgiDeck deck) {
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
                  BilgiDataManager.saveData();
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
          ? const Center(child: Text('Deste yok.', style: TextStyle(color: Colors.white54)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: widget.unit.decks.length,
              itemBuilder: (context, index) {
                final deck = widget.unit.decks[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BilgiStudyScreen(deck: deck)))
                        .then((_) => setState(() {}));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.5), width: 2),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.style_rounded, color: Colors.tealAccent, size: 28),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDeleteDeck(deck),
                              tooltip: 'Desteyi Sil',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
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
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Deste Ekle', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- 4. KART OLUŞTURMA & DÜZENLEME & ÇİZİM EDİTÖRÜ ---
class BilgiCardEditScreen extends StatefulWidget {
  final BilgiDeck deck;
  final BilgiCardItem? cardToEdit;
  const BilgiCardEditScreen({super.key, required this.deck, this.cardToEdit});

  @override
  State<BilgiCardEditScreen> createState() => _BilgiCardEditScreenState();
}

class _BilgiCardEditScreenState extends State<BilgiCardEditScreen> {
  List<TextSegment> _segments = [
    TextSegment(text: '')
  ];
  final List<TextEditingController> _controllers = [];
  final List<DrawingStroke> _strokes = [];
  late final ValueNotifier<List<DrawingStroke>> _strokesNotifier;
  
  Color _selectedColor = Colors.black;
  double _strokeSize = 4.0;
  double _strokeOpacity = 1.0;
  bool _isEraser = false;
  bool _canScroll = true;

  Color _cardColor = Colors.white;

  final List<Color> _presetCardColors = [
    Colors.white,
    Colors.yellow.shade100,
    Colors.orange.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
    Colors.purple.shade100,
    Colors.pink.shade100,
    Colors.grey.shade900,
  ];

  final List<Color> _presetTextColors = [
    Colors.black87,
    Colors.redAccent,
    Colors.blueAccent,
    Colors.green,
    Colors.purple,
    Colors.white,
  ];

  final TextEditingController _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.cardToEdit != null) {
      _cardColor = Color(widget.cardToEdit!.cardColorValue);
      _strokes.addAll(widget.cardToEdit!.strokes.map((s) => DrawingStroke(
        points: List.from(s.points),
        color: s.color,
        strokeWidth: s.strokeWidth,
        opacity: s.opacity,
        isEraser: s.isEraser,
      )));
      if (widget.cardToEdit!.segments.isNotEmpty) {
        _segments = widget.cardToEdit!.segments.map((seg) => TextSegment(
          text: seg.text,
          isBold: seg.isBold,
          isItalic: seg.isItalic,
          isUnderline: seg.isUnderline,
          isStrikethrough: seg.isStrikethrough,
          textColorValue: seg.textColorValue,
        )).toList();
      }
    }
    _strokesNotifier = ValueNotifier<List<DrawingStroke>>(_strokes);
    _initControllers();
  }

  void _initControllers() {
    for (var seg in _segments) {
      final ctrl = TextEditingController(text: seg.text);
      ctrl.addListener(() {
        seg.text = ctrl.text;
        setState(() {});
      });
      _controllers.add(ctrl);
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    _hexController.dispose();
    _strokesNotifier.dispose();
    super.dispose();
  }

  void _addSegment() {
    setState(() {
      final seg = TextSegment(text: '');
      _segments.add(seg);
      final ctrl = TextEditingController(text: '');
      ctrl.addListener(() {
        seg.text = ctrl.text;
        setState(() {});
      });
      _controllers.add(ctrl);
    });
  }

  void _removeSegment(int index) {
    if (_segments.length > 1) {
      setState(() {
        _controllers[index].dispose();
        _controllers.removeAt(index);
        _segments.removeAt(index);
      });
    }
  }

  void _addCustomCardColorFromHex(String hexCode) {
    try {
      String cleanHex = hexCode.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      int colorInt = int.parse(cleanHex, radix: 16);
      setState(() {
        _cardColor = Color(colorInt);
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçersiz renk kodu! (Örn: #FF5733)')),
      );
    }
  }

  void _showCardColorPickerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Özel Kart Rengi (Hex)', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _hexController,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '#FF5733',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => _addCustomCardColorFromHex(_hexController.text),
              child: const Text('Uygula', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _saveCard() {
    if (_segments.every((s) => s.text.trim().isEmpty) && _strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kart boş olamaz!')));
      return;
    }
    final updatedCard = BilgiCardItem(
      segments: _segments.map((s) => TextSegment(
        text: s.text,
        isBold: s.isBold,
        isItalic: s.isItalic,
        isUnderline: s.isUnderline,
        isStrikethrough: s.isStrikethrough,
        textColorValue: s.textColorValue,
      )).toList(),
      strokes: List.from(_strokes),
      cardColorValue: _cardColor.toARGB32(),
    );

    if (widget.cardToEdit != null) {
      int index = widget.deck.cards.indexOf(widget.cardToEdit!);
      if (index != -1) {
        widget.deck.cards[index] = updatedCard;
      } else {
        widget.deck.cards.add(updatedCard);
      }
    } else {
      widget.deck.cards.add(updatedCard);
    }

    BilgiDataManager.saveData();
    Navigator.pop(context, updatedCard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.cardToEdit != null ? 'Bilgi Kartını Düzenle' : 'Yeni Bilgi Kartı Ekle'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.tealAccent),
            onPressed: _saveCard,
            tooltip: 'Kartı Kaydet',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: _canScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Canlı Kart Önizlemesi', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Center(
              child: Listener(
                onPointerDown: (_) => setState(() => _canScroll = false),
                onPointerUp: (_) => setState(() => _canScroll = true),
                onPointerCancel: (_) => setState(() => _canScroll = true),
                child: buildCardBody(
                  cardColor: _cardColor,
                  segments: _segments,
                  strokes: _strokes,
                  strokesNotifier: _strokesNotifier,
                  isInteractive: true,
                  onPanStart: (localPosition) {
                    _strokes.add(DrawingStroke(
                      points: [localPosition],
                      color: _isEraser ? _cardColor : _selectedColor,
                      strokeWidth: _isEraser ? _strokeSize * 3 : _strokeSize,
                      opacity: _isEraser ? 1.0 : _strokeOpacity,
                      isEraser: _isEraser,
                    ));
                    _strokesNotifier.value = List.from(_strokes);
                  },
                  onPanUpdate: (localPosition) {
                    if (_strokes.isNotEmpty) {
                      _strokes.last.points.add(localPosition);
                      _strokesNotifier.value = List.from(_strokes);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Metin Blokları ve Stiller', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _segments.length,
              itemBuilder: (context, index) {
                final seg = _segments[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[index],
                              maxLines: null,
                              autofocus: false,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Metin bloğu (${index + 1})...',
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF121212),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          if (_segments.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _removeSegment(index),
                              tooltip: 'Bloğu Sil',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          ToggleButtons(
                            borderColor: Colors.white24,
                            selectedBorderColor: Colors.tealAccent,
                            selectedColor: Colors.black,
                            color: Colors.white,
                            fillColor: Colors.tealAccent.shade100,
                            borderRadius: BorderRadius.circular(6),
                            isSelected: [seg.isBold, seg.isItalic, seg.isUnderline, seg.isStrikethrough],
                            onPressed: (btnIndex) {
                              setState(() {
                                if (btnIndex == 0) seg.isBold = !seg.isBold;
                                if (btnIndex == 1) seg.isItalic = !seg.isItalic;
                                if (btnIndex == 2) seg.isUnderline = !seg.isUnderline;
                                if (btnIndex == 3) seg.isStrikethrough = !seg.isStrikethrough;
                              });
                            },
                            children: const [
                              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.format_bold, size: 16)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.format_italic, size: 16)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.format_underlined, size: 16)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.strikethrough_s, size: 16)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Yazı Rengi:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              const SizedBox(width: 4),
                              for (var tCol in _presetTextColors)
                                GestureDetector(
                                  onTap: () => setState(() => seg.textColorValue = tCol.toARGB32()),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: tCol,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: seg.textColorValue == tCol.toARGB32() ? Colors.tealAccent : Colors.white24,
                                        width: seg.textColorValue == tCol.toARGB32() ? 2 : 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _addSegment,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Metin Bloğu Ekle'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kart Arka Plan Rengi:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (Color col in _presetCardColors)
                          GestureDetector(
                            onTap: () => setState(() => _cardColor = col),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _cardColor.toARGB32() == col.toARGB32() ? Colors.tealAccent : Colors.white54,
                                  width: _cardColor.toARGB32() == col.toARGB32() ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, color: Colors.white, size: 16),
                          label: const Text('Hex Ekle', style: TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.teal.shade800,
                          onPressed: _showCardColorPickerDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _colorButton(Colors.black, 'Siyah'),
                      _colorButton(Colors.redAccent, 'Kırmızı'),
                      _colorButton(Colors.blueAccent, 'Mavi'),
                      IconButton(
                        icon: Icon(Icons.cleaning_services_rounded, color: _isEraser ? Colors.tealAccent : Colors.white70),
                        onPressed: () => setState(() => _isEraser = true),
                        tooltip: 'Silgi',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white54),
                        onPressed: () {
                          setState(() {
                            _strokes.clear();
                            _strokesNotifier.value = [];
                          });
                        },
                        tooltip: 'Temizle',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Boyut:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _strokeSize,
                          min: 1.0,
                          max: 20.0,
                          activeColor: Colors.tealAccent,
                          onChanged: (v) => setState(() => _strokeSize = v),
                        ),
                      ),
                      Text(_strokeSize.toStringAsFixed(1), style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Opaklık:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _strokeOpacity,
                          min: 0.1,
                          max: 1.0,
                          activeColor: Colors.tealAccent,
                          onChanged: (v) => setState(() => _strokeOpacity = v),
                        ),
                      ),
                      Text('${(_strokeOpacity * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveCard,
                icon: const Icon(Icons.check),
                label: const Text('Kartı Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(Color color, String label) {
    bool isSelected = !_isEraser && _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedColor = color;
        _isEraser = false;
      }),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.tealAccent : Colors.transparent, width: 3),
        ),
      ),
    );
  }
}

class CardDrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  CardDrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      Paint paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- 5. ÇALIŞMA EKRANI ---
class BilgiStudyScreen extends StatefulWidget {
  final BilgiDeck deck;
  const BilgiStudyScreen({super.key, required this.deck});

  @override
  State<BilgiStudyScreen> createState() => _BilgiStudyScreenState();
}

class _BilgiStudyScreenState extends State<BilgiStudyScreen> with SingleTickerProviderStateMixin {
  late List<BilgiCardItem> _cards;
  BilgiCardItem? _exitingCard;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _loadCards();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(1.5, -1.5)).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _rotateAnim = Tween<double>(begin: 0, end: 0.3).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  void _loadCards() {
    // İlk girişte kart ekleme sırasıyla (sıralı) gelsin
    _cards = List.from(widget.deck.cards);
    _exitingCard = null;
  }

  void _shuffleRemainingCards() {
    if (_cards.length > 1) {
      setState(() {
        // Aktif olarak gösterilen ilk kartı sabit tut, arkadaki kalan kartları karıştır
        final currentCard = _cards.removeAt(0);
        _cards.shuffle();
        _cards.insert(0, currentCard);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kalan kartlar karıştırıldı!'), duration: Duration(milliseconds: 800)),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _flingCard() {
    if (_cards.isEmpty || _animController.isAnimating) return;

    setState(() {
      _exitingCard = _cards.removeAt(0);
    });

    _animController.forward().then((_) {
      setState(() {
        _animController.reset();
        _exitingCard = null;
        if (_cards.isEmpty) {
          _showFinishedDialog();
        }
      });
    });
  }

  void _confirmDeleteCurrentCard() {
    if (_cards.isEmpty || _animController.isAnimating) return;
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
                  final cardToDelete = _cards.removeAt(0);
                  widget.deck.cards.remove(cardToDelete);
                  BilgiDataManager.saveData();

                  if (_cards.isEmpty) {
                    _showFinishedDialog();
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

  void _showFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.5))),
          title: const Text('Tebrikler!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: const Text('Bu destedeki tüm bilgi kartlarını bitirdin!', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _loadCards();
                });
              },
              child: const Text('Baştan Başla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: Text(widget.deck.title),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle, color: Colors.tealAccent),
            onPressed: _shuffleRemainingCards,
            tooltip: 'Kalan Kartları Karıştır',
          ),
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: Colors.tealAccent),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => BilgiCardEditScreen(deck: widget.deck)));
              setState(() {
                _loadCards();
              });
            },
            tooltip: 'Kart Ekle',
          ),
        ],
      ),
      body: _cards.isEmpty && _exitingCard == null
          ? Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => BilgiCardEditScreen(deck: widget.deck)));
                  setState(() {
                    _loadCards();
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('İlk Bilgi Kartını Ekle', style: TextStyle(color: Colors.white)),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      height: 420,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (_cards.length > 2)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: -16,
                              bottom: -16,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2), width: 1.5),
                                ),
                              ),
                            ),
                          if (_cards.length > 1)
                            Positioned(
                              top: 8,
                              left: 8,
                              right: -8,
                              bottom: -8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4), width: 1.5),
                                ),
                              ),
                            ),
                          if (_cards.isNotEmpty)
                            GestureDetector(
                              onTap: _flingCard,
                              onVerticalDragUpdate: (details) {
                                if (details.delta.dy < -5) _flingCard();
                              },
                              child: buildCardBody(
                                cardColor: Color(_cards.first.cardColorValue),
                                segments: _cards.first.segments,
                                strokes: _cards.first.strokes,
                              ),
                            ),
                          if (_exitingCard != null)
                            SlideTransition(
                              position: _slideAnim,
                              child: RotationTransition(
                                turns: _rotateAnim,
                                child: buildCardBody(
                                  cardColor: Color(_exitingCard!.cardColorValue),
                                  segments: _exitingCard!.segments,
                                  strokes: _exitingCard!.strokes,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Kartı geçmek için yukarı kaydırın veya dokunun',
                        style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.tealAccent, size: 24),
                        onPressed: () async {
                          if (_cards.isNotEmpty) {
                            final currentCard = _cards.first;
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BilgiCardEditScreen(
                                  deck: widget.deck,
                                  cardToEdit: currentCard,
                                ),
                              ),
                            );
                            if (result is BilgiCardItem) {
                              setState(() {
                                _cards[0] = result;
                              });
                            }
                          }
                        },
                        tooltip: 'Bu Kartı Düzenle',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                        onPressed: _confirmDeleteCurrentCard,
                        tooltip: 'Bu Kartı Sil',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// --- 6. TEST SEÇİM EKRANI ---
class BilgiTestSetupScreen extends StatefulWidget {
  const BilgiTestSetupScreen({super.key});

  @override
  State<BilgiTestSetupScreen> createState() => _BilgiTestSetupScreenState();
}

class _BilgiTestSetupScreenState extends State<BilgiTestSetupScreen> {
  final Set<BilgiSubject> _selectedSubjects = {};
  final Set<BilgiUnit> _selectedUnits = {};
  final Set<BilgiDeck> _selectedDecks = {};

  List<BilgiUnit> get _availableUnits {
    List<BilgiUnit> units = [];
    for (var subject in _selectedSubjects) {
      units.addAll(subject.units);
    }
    return units;
  }

  List<BilgiDeck> get _availableDecks {
    List<BilgiDeck> decks = [];
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
    int totalCards = _selectedDecks.fold(0, (sum, deck) => sum + deck.cards.length);
    if (totalCards == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçtiğiniz destelerde hiç kart yok!')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BilgiTestActiveScreen(selectedDecks: _selectedDecks.toList())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Bilgi Kartı Test Ayarları'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Ders Seçimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
              child: Column(
                children: BilgiDataManager.subjects.map((subject) {
                  return CheckboxListTile(
                    title: Text(subject.title, style: const TextStyle(color: Colors.white)),
                    value: _selectedSubjects.contains(subject),
                    activeColor: Colors.teal,
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
              const Text('2. Ünite Seçimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                child: Column(
                  children: _availableUnits.map((unit) {
                    return CheckboxListTile(
                      title: Text(unit.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${unit.decks.length} Deste', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      value: _selectedUnits.contains(unit),
                      activeColor: Colors.teal,
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
              const Text('3. Deste Seçimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                child: Column(
                  children: _availableDecks.map((deck) {
                    return CheckboxListTile(
                      title: Text(deck.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${deck.cards.length} Kart', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      value: _selectedDecks.contains(deck),
                      activeColor: Colors.teal,
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
              const SizedBox(height: 40),
            ],
            if (_selectedDecks.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _startTest,
                  child: const Text('TESTE BAŞLA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
class BilgiTestActiveScreen extends StatefulWidget {
  final List<BilgiDeck> selectedDecks;
  const BilgiTestActiveScreen({super.key, required this.selectedDecks});

  @override
  State<BilgiTestActiveScreen> createState() => _BilgiTestActiveScreenState();
}

class _BilgiTestActiveScreenState extends State<BilgiTestActiveScreen> with SingleTickerProviderStateMixin {
  late List<BilgiCardItem> _cards;
  BilgiCardItem? _exitingCard;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _loadTestCards();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(1.5, -1.5)).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _rotateAnim = Tween<double>(begin: 0, end: 0.3).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  void _loadTestCards() {
    List<BilgiCardItem> pool = [];
    for (var deck in widget.selectedDecks) {
      pool.addAll(deck.cards);
    }
    pool.shuffle();
    _cards = pool;
    _exitingCard = null;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _flingCard() {
    if (_cards.isEmpty || _animController.isAnimating) return;

    setState(() {
      _exitingCard = _cards.removeAt(0);
    });

    _animController.forward().then((_) {
      setState(() {
        _animController.reset();
        _exitingCard = null;
        if (_cards.isEmpty) {
          _showFinishedDialog();
        }
      });
    });
  }

  void _confirmDeleteTestCard() {
    if (_cards.isEmpty || _animController.isAnimating) return;
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
                  final cardToDelete = _cards.removeAt(0);
                  for (var deck in widget.selectedDecks) {
                    deck.cards.remove(cardToDelete);
                  }
                  BilgiDataManager.saveData();

                  if (_cards.isEmpty) {
                    _showFinishedDialog();
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

  void _showFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.5))),
          title: const Text('Tebrikler!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: const Text('Seçtiğiniz test oturumundaki tüm bilgi kartlarını bitirdiniz!', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Çık', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _loadTestCards();
                });
              },
              child: const Text('Baştan Başla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: const Text('Bilgi Kartı Testi'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: _cards.isEmpty && _exitingCard == null
          ? const Center(child: Text('Kart bulunamadı.', style: TextStyle(color: Colors.white54)))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      height: 420,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (_cards.length > 2)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: -16,
                              bottom: -16,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2), width: 1.5),
                                ),
                              ),
                            ),
                          if (_cards.length > 1)
                            Positioned(
                              top: 8,
                              left: 8,
                              right: -8,
                              bottom: -8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4), width: 1.5),
                                ),
                              ),
                            ),
                          if (_cards.isNotEmpty)
                            GestureDetector(
                              onTap: _flingCard,
                              onVerticalDragUpdate: (details) {
                                if (details.delta.dy < -5) _flingCard();
                              },
                              child: buildCardBody(
                                cardColor: Color(_cards.first.cardColorValue),
                                segments: _cards.first.segments,
                                strokes: _cards.first.strokes,
                              ),
                            ),
                          if (_exitingCard != null)
                            SlideTransition(
                              position: _slideAnim,
                              child: RotationTransition(
                                turns: _rotateAnim,
                                child: buildCardBody(
                                  cardColor: Color(_exitingCard!.cardColorValue),
                                  segments: _exitingCard!.segments,
                                  strokes: _exitingCard!.strokes,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Kartı geçmek için yukarı kaydırın veya dokunun',
                        style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.tealAccent, size: 24),
                        onPressed: () async {
                          if (_cards.isNotEmpty) {
                            final currentCard = _cards.first;
                            BilgiDeck? parentDeck;
                            for (var deck in widget.selectedDecks) {
                              if (deck.cards.contains(currentCard)) {
                                parentDeck = deck;
                                break;
                              }
                            }
                            if (parentDeck != null) {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BilgiCardEditScreen(
                                    deck: parentDeck!,
                                    cardToEdit: currentCard,
                                  ),
                                ),
                              );
                              if (result is BilgiCardItem) {
                                setState(() {
                                  _cards[0] = result;
                                });
                              }
                            }
                          }
                        },
                        tooltip: 'Bu Kartı Düzenle',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                        onPressed: _confirmDeleteTestCard,
                        tooltip: 'Bu Kartı Sil',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}