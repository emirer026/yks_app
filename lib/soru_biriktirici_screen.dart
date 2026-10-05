// NOT: Bu dosyanın çalışması için pubspec.yaml dosyanıza şu paketi eklemeniz gerekir
// (fotoğrafları kalıcı bir klasöre kopyalamak için kullanılıyor, aksi halde
// image_picker'ın döndürdüğü geçici dosya yolu silinip görseller kaybolabilir):
//
// dependencies:
//   path_provider: ^2.1.4
//
// Ekledikten sonra: flutter pub get

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'user_data_service.dart';

// --- ORTAK YARDIMCILAR ---

const List<Color> kPaletteColors = [
  Colors.black,
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.brown,
  Colors.pink,
];

String fileExtension(String path) {
  final idx = path.lastIndexOf('.');
  if (idx == -1 || idx == path.length - 1) return '.jpg';
  return path.substring(idx);
}

IconData subjectIcon(String subject) {
  switch (subject) {
    case 'Türkçe':
    case 'Edebiyat':
      return Icons.menu_book_rounded;
    case 'Tarih':
    case 'Tarih-1':
      return Icons.account_balance_rounded;
    case 'Coğrafya':
    case 'Coğrafya-1':
      return Icons.public_rounded;
    case 'Felsefe':
      return Icons.psychology_rounded;
    case 'Matematik':
      return Icons.functions_rounded;
    case 'Geometri':
      return Icons.change_history_rounded;
    case 'Fizik':
      return Icons.bolt_rounded;
    case 'Kimya':
      return Icons.science_rounded;
    case 'Biyoloji':
      return Icons.eco_rounded;
    default:
      return Icons.book_rounded;
  }
}

Color subjectColor(String subject) {
  const colors = [
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.greenAccent,
    Colors.amberAccent,
    Colors.redAccent,
    Colors.lightBlueAccent,
    Colors.tealAccent,
  ];
  return colors[subject.hashCode.abs() % colors.length];
}

// --- VERİ MODELLERİ ---

class CanvasItem {
  String id;
  String type; // 'image' veya 'text'
  String content; // Resim yolu veya metin
  double x;
  double y;
  double width; // Resimler için genişlik
  double fontSize; // Metinler için yazı boyutu
  bool locked;
  int? colorValue;
  bool bold;
  bool italic;
  bool underline;
  bool strike;

  CanvasItem({
    required this.id,
    required this.type,
    required this.content,
    required this.x,
    required this.y,
    this.width = 200.0,
    this.fontSize = 16.0,
    this.locked = false,
    this.colorValue,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
        'x': x,
        'y': y,
        'width': width,
        'fontSize': fontSize,
        'locked': locked,
        'colorValue': colorValue,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'strike': strike,
      };

  factory CanvasItem.fromJson(Map<String, dynamic> json) => CanvasItem(
        id: json['id'] ?? UniqueKey().toString(),
        type: json['type'] ?? 'text',
        content: json['content'] ?? '',
        x: (json['x'] ?? 50.0).toDouble(),
        y: (json['y'] ?? 50.0).toDouble(),
        width: (json['width'] ?? 200.0).toDouble(),
        fontSize: (json['fontSize'] ?? 16.0).toDouble(),
        locked: json['locked'] ?? false,
        colorValue: json['colorValue'],
        bold: json['bold'] ?? false,
        italic: json['italic'] ?? false,
        underline: json['underline'] ?? false,
        strike: json['strike'] ?? false,
      );
}

class Stroke {
  List<Map<String, double>> points;
  int colorValue;
  double width;
  double opacity;

  Stroke({
    required this.points,
    required this.colorValue,
    required this.width,
    required this.opacity,
  });

  Map<String, dynamic> toJson() => {
        'points': points,
        'color': colorValue,
        'width': width,
        'opacity': opacity,
      };

  static List<Map<String, double>> _parsePoints(List raw) {
    List<Map<String, double>> pts = [];
    for (var ptObj in raw) {
      if (ptObj is Map) {
        double dx = double.tryParse(ptObj['dx']?.toString() ?? '0') ?? 0.0;
        double dy = double.tryParse(ptObj['dy']?.toString() ?? '0') ?? 0.0;
        pts.add({'dx': dx, 'dy': dy});
      }
    }
    return pts;
  }

  factory Stroke.fromJson(dynamic json) {
    if (json is List) {
      return Stroke(
        points: _parsePoints(json),
        colorValue: Colors.black.toARGB32(),
        width: 3.0,
        opacity: 1.0,
      );
    }
    final map = json as Map<String, dynamic>;
    return Stroke(
      points: _parsePoints(map['points'] as List? ?? []),
      colorValue: map['color'] ?? Colors.black.toARGB32(),
      width: (map['width'] ?? 3.0).toDouble(),
      opacity: (map['opacity'] ?? 1.0).toDouble(),
    );
  }
}

class BookPageData {
  String id;
  List<CanvasItem> items;
  List<Stroke> strokes;

  BookPageData({required this.id, required this.items, required this.strokes});

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory BookPageData.fromJson(Map<String, dynamic> json) {
    var rawStrokes = json['strokes'] as List? ?? [];
    List<Stroke> parsedStrokes = rawStrokes.map((s) => Stroke.fromJson(s)).toList();

    var rawItems = json['items'] as List? ?? [];
    List<CanvasItem> parsedItems =
        rawItems.map((i) => CanvasItem.fromJson(i as Map<String, dynamic>)).toList();

    return BookPageData(
      id: json['id'] ?? UniqueKey().toString(),
      items: parsedItems,
      strokes: parsedStrokes,
    );
  }
}

class QuestionBook {
  String id;
  String name;
  String subject;
  String category;

  QuestionBook({required this.id, required this.name, required this.subject, required this.category});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'subject': subject, 'category': category};

  factory QuestionBook.fromJson(Map<String, dynamic> json) => QuestionBook(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        subject: json['subject'] ?? '',
        category: json['category'] ?? 'TYT',
      );
}

// --- ANA EKRAN ---

class SoruBiriktiriciScreen extends StatelessWidget {
  const SoruBiriktiriciScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Soru Biriktirici'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBigButton(
                context,
                title: 'Ders Seçimi (TYT / AYT)',
                icon: Icons.menu_book_rounded,
                color: Colors.amberAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TytAytSelectionScreen())),
              ),
              const SizedBox(height: 25),
              _buildBigButton(
                context,
                title: 'Özel Arşiv',
                icon: Icons.folder_special_rounded,
                color: Colors.pinkAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookListScreen(subject: 'Özel Arşiv', category: 'OZEL'))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigButton(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- TYT / AYT SEÇİM EKRANI ---

class TytAytSelectionScreen extends StatelessWidget {
  const TytAytSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('Sınav Türü'), backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _card(context, 'TYT Dersleri', Colors.orangeAccent, 'TYT'),
            const SizedBox(height: 20),
            _card(context, 'AYT Dersleri', Colors.purpleAccent, 'AYT'),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, Color color, String category) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectListScreen(category: category))),
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)),
        child: Center(child: Text(title, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

// --- DERSLER LİSTESİ ---

class SubjectListScreen extends StatelessWidget {
  final String category;
  const SubjectListScreen({super.key, required this.category});

  static const List<String> tytSubjects = [
    'Türkçe', 'Tarih', 'Coğrafya', 'Felsefe', 'Matematik', 'Geometri', 'Fizik', 'Kimya', 'Biyoloji'
  ];
  static const List<String> aytSubjects = [
    'Edebiyat', 'Tarih-1', 'Coğrafya-1', 'Matematik', 'Geometri', 'Fizik', 'Kimya', 'Biyoloji'
  ];

  @override
  Widget build(BuildContext context) {
    List<String> subjects = category == 'TYT' ? tytSubjects : aytSubjects;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: Text('$category Dersleri'), backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          String sub = subjects[index];
          final color = subjectColor(sub);
          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: color.withValues(alpha: 0.35)),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(subjectIcon(sub), color: color)),
              title: Text(sub, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BookListScreen(subject: sub, category: category))),
            ),
          );
        },
      ),
    );
  }
}

// --- KİTAP / DENEME LİSTESİ ---

class BookListScreen extends StatefulWidget {
  final String subject;
  final String category;
  const BookListScreen({super.key, required this.subject, required this.category});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  List<QuestionBook> books = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  String get _storageKey => 'question_books_${widget.category}_${widget.subject}';

  Future<void> _loadBooks() async {
    final allData = await UserDataService.fetchAllData();
    String? saved = allData[_storageKey];
    List<QuestionBook> loaded = [];
    if (saved != null && saved.isNotEmpty) {
      List decoded = jsonDecode(saved);
      loaded = decoded.map((e) => QuestionBook.fromJson(e)).toList();
    }
    if (!mounted) return;
    setState(() {
      books = loaded;
      isLoading = false;
    });
  }

  Future<void> _saveBooks() async {
    String encoded = jsonEncode(books.map((e) => e.toJson()).toList());
    await UserDataService.saveModuleData(_storageKey, encoded);
  }

  void _showAddBookDialog({QuestionBook? editing}) {
    TextEditingController nameCtrl = TextEditingController(text: editing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          editing == null ? "Yeni Soru Defteri/Deneme" : "Defteri Yeniden Adlandır",
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Örn: 3. Deneme",
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
            onPressed: () {
              final text = nameCtrl.text.trim();
              if (text.isEmpty) return;
              setState(() {
                if (editing == null) {
                  books.insert(0, QuestionBook(id: UniqueKey().toString(), name: text, subject: widget.subject, category: widget.category));
                } else {
                  editing.name = text;
                }
                _saveBooks();
              });
              Navigator.pop(ctx);
            },
            child: Text(editing == null ? "Oluştur" : "Kaydet", style: const TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }

  void _confirmDelete(QuestionBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Emin misin?", style: TextStyle(color: Colors.white)),
        content: Text('"${book.name}" kalıcı olarak silinecek.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                books.removeWhere((b) => b.id == book.id);
                _saveBooks();
              });
              Navigator.pop(ctx);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = searchQuery.isEmpty
        ? books
        : books.where((b) => b.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: Text(widget.subject), backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amberAccent,
        onPressed: () => _showAddBookDialog(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Column(
              children: [
                if (books.length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Defter ara...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_off_outlined, color: Colors.white24, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                books.isEmpty ? "Henüz bir defter eklenmemiş." : "Sonuç bulunamadı.",
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            var book = filtered[index];
                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFF2A2A2A),
                                  child: Icon(Icons.description_outlined, color: Colors.amberAccent),
                                ),
                                title: Text(book.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.white54),
                                      onPressed: () => _showAddBookDialog(editing: book),
                                      tooltip: 'Yeniden adlandır',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _confirmDelete(book),
                                      tooltip: 'Sil',
                                    ),
                                  ],
                                ),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QuestionNotebookScreen(book: book))),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// --- GERÇEKÇİ A4 DEFTER VE ÇİZİM Ekrani ---

enum NotebookToolMode { panZoom, draw, edit }

class QuestionNotebookScreen extends StatefulWidget {
  final QuestionBook book;
  const QuestionNotebookScreen({super.key, required this.book});

  @override
  State<QuestionNotebookScreen> createState() => _QuestionNotebookScreenState();
}

class _QuestionNotebookScreenState extends State<QuestionNotebookScreen> {
  static const double pageWidth = 595.0;
  static const double pageHeight = 842.0;

  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();
  final TransformationController _transformationController = TransformationController();
  
  final Set<int> _activePointers = {};
  bool _isMultiTouch = false;

  List<BookPageData> pages = [BookPageData(id: 'initial', items: [], strokes: [])];
  int currentPageIndex = 0;

  NotebookToolMode currentToolMode = NotebookToolMode.panZoom;
  Color drawColor = Colors.black;
  double strokeWidth = 3.0;
  double strokeOpacity = 1.0;
  double eraserWidth = 25.0;
  bool isEraser = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetToDefaultView() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    
    double scale = (size.width - 32) / pageWidth;
    scale = scale.clamp(0.2, 1.5);
    
    final expectedX = (size.width - (pageWidth * scale)) / 2;
    final expectedY = 40.0; 

    _transformationController.value = Matrix4.identity()
      ..translate(expectedX, expectedY)
      ..scale(scale);
  }

  String get _storageKey => 'question_pages_${widget.book.id}';

  Future<void> _loadBookData() async {
    final allData = await UserDataService.fetchAllData();
    String? saved = allData[_storageKey];
    if (saved != null && saved.isNotEmpty) {
      List decoded = jsonDecode(saved);
      final loadedPages = decoded.map((e) => BookPageData.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        pages = loadedPages.isEmpty ? pages : loadedPages;
        isLoading = false;
      });
    } else {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetToDefaultView();
    });
  }

  Future<void> _saveBookData() async {
    String encoded = jsonEncode(pages.map((p) => p.toJson()).toList());
    await UserDataService.saveModuleData(_storageKey, encoded);
  }

  BookPageData get _currentPage => pages[currentPageIndex];

  void _addNewPage() {
    setState(() {
      pages.add(BookPageData(id: UniqueKey().toString(), items: [], strokes: []));
    });
    _saveBookData();
    Future.microtask(() {
      if (_pageController.hasClients) {
        _pageController.animateToPage(pages.length - 1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    });
    _resetToDefaultView();
  }

  Future<String> _persistImage(XFile file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/soru_biriktirici_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final ext = fileExtension(file.path);
    final newPath = '${imagesDir.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    final newFile = await File(file.path).copy(newPath);
    return newFile.path;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;
      final savedPath = await _persistImage(image);
      final stagger = (_currentPage.items.length % 6) * 18.0;
      setState(() {
        _currentPage.items.add(CanvasItem(
          id: UniqueKey().toString(),
          type: 'image',
          content: savedPath,
          x: 80.0 + stagger,
          y: 80.0 + stagger,
          width: 250.0,
        ));
      });
      _saveBookData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Görsel eklenemedi: $e')));
    }
  }

  void _addTextBox() {
    final stagger = (_currentPage.items.length % 6) * 18.0;
    setState(() {
      _currentPage.items.add(CanvasItem(
        id: UniqueKey().toString(),
        type: 'text',
        content: 'Çift tıkla düzenle',
        x: 80.0 + stagger,
        y: 80.0 + stagger,
        colorValue: Colors.black.toARGB32(),
      ));
    });
    _saveBookData();
  }

  void _editTextBox(CanvasItem item) {
    TextEditingController ctrl = TextEditingController(text: item.content);
    int colVal = item.colorValue ?? Colors.black.toARGB32();
    bool bold = item.bold;
    bool italic = item.italic;
    bool underline = item.underline;
    bool strike = item.strike;
    double fontSize = item.fontSize;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Metni Düzenle", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: "Yazı girin...", hintStyle: TextStyle(color: Colors.white38)),
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(icon: Icon(Icons.format_bold, color: bold ? Colors.cyanAccent : Colors.white54), onPressed: () => setDlgState(() => bold = !bold)),
                    IconButton(icon: Icon(Icons.format_italic, color: italic ? Colors.cyanAccent : Colors.white54), onPressed: () => setDlgState(() => italic = !italic)),
                    IconButton(icon: Icon(Icons.format_underlined, color: underline ? Colors.cyanAccent : Colors.white54), onPressed: () => setDlgState(() => underline = !underline)),
                    IconButton(icon: Icon(Icons.strikethrough_s, color: strike ? Colors.cyanAccent : Colors.white54), onPressed: () => setDlgState(() => strike = !strike)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Boyut', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 10,
                        max: 36,
                        activeColor: Colors.amberAccent,
                        onChanged: (v) => setDlgState(() => fontSize = v),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in kPaletteColors) _colorDot(c, colVal, (v) => setDlgState(() => colVal = v)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.redAccent))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
              onPressed: () {
                setState(() {
                  final trimmed = ctrl.text.trim();
                  item.content = trimmed.isEmpty ? item.content : trimmed;
                  item.colorValue = colVal;
                  item.bold = bold;
                  item.italic = italic;
                  item.underline = underline;
                  item.strike = strike;
                  item.fontSize = fontSize;
                });
                _saveBookData();
                Navigator.pop(ctx);
              },
              child: const Text("Kaydet", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color c, int selectedVal, Function(int) onTap) {
    return GestureDetector(
      onTap: () => onTap(c.toARGB32()),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: selectedVal == c.toARGB32() ? Colors.white : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Kalem ve Silgi Ayarları", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Kalem Kalınlığı", style: TextStyle(color: Colors.white70)),
              Slider(
                value: strokeWidth,
                min: 1.0,
                max: 20.0,
                activeColor: Colors.amberAccent,
                onChanged: (val) => setDlgState(() => setState(() => strokeWidth = val)),
              ),
              const Text("Silgi Kalınlığı", style: TextStyle(color: Colors.white70)),
              Slider(
                value: eraserWidth,
                min: 10.0,
                max: 60.0,
                activeColor: Colors.cyanAccent,
                onChanged: (val) => setDlgState(() => setState(() => eraserWidth = val)),
              ),
              const Text("Kalem Opaklığı", style: TextStyle(color: Colors.white70)),
              Slider(
                value: strokeOpacity,
                min: 0.1,
                max: 1.0,
                activeColor: Colors.greenAccent,
                onChanged: (val) => setDlgState(() => setState(() => strokeOpacity = val)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kapat", style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _confirmClearPageDrawings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Emin misin?', style: TextStyle(color: Colors.white)),
        content: const Text('Bu sayfadaki tüm çizimler silinecek (fotoğraf ve metinler etkilenmez).', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() => _currentPage.strokes = []);
              _saveBookData();
              Navigator.pop(ctx);
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePage() {
    if (pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tek sayfa kaldığı için silinemez.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Sayfayı Sil', style: TextStyle(color: Colors.white)),
        content: Text('Sayfa ${currentPageIndex + 1} ve tüm içeriği kalıcı olarak silinecek.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                pages.removeAt(currentPageIndex);
                if (currentPageIndex >= pages.length) currentPageIndex = pages.length - 1;
              });
              _saveBookData();
              Navigator.pop(ctx);
              Future.microtask(() {
                if (_pageController.hasClients) _pageController.jumpToPage(currentPageIndex);
              });
              _resetToDefaultView();
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _undoLastStroke() {
    if (_currentPage.strokes.isEmpty) return;
    setState(() => _currentPage.strokes.removeLast());
    _saveBookData();
  }

  void _eraseAt(Offset pos) {
    final page = _currentPage;
    final double r = eraserWidth;
    final List<Stroke> newStrokes = [];
    bool changed = false;

    for (var s in page.strokes) {
      List<Map<String, double>> current = [];
      for (var pt in s.points) {
        final d = (Offset(pt['dx']!, pt['dy']!) - pos).distance;
        if (d <= r) {
          changed = true;
          if (current.length >= 2) {
            newStrokes.add(Stroke(points: List.of(current), colorValue: s.colorValue, width: s.width, opacity: s.opacity));
          }
          current = [];
        } else {
          current.add(pt);
        }
      }
      if (current.length >= 2) {
        newStrokes.add(Stroke(points: current, colorValue: s.colorValue, width: s.width, opacity: s.opacity));
      } else if (current.length < 2 && !changed) {
        newStrokes.add(s);
      }
    }

    if (changed) {
      setState(() => page.strokes = newStrokes);
    }
  }

  void _showPageJumpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Sayfaya Git', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(pages.length, (i) {
              final selected = i == currentPageIndex;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  if (_pageController.hasClients) _pageController.jumpToPage(i);
                },
                child: CircleAvatar(
                  backgroundColor: selected ? Colors.amberAccent : Colors.white24,
                  child: Text('${i + 1}', style: TextStyle(color: selected ? Colors.black : Colors.white)),
                ),
              );
            }),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.amberAccent),
              title: const Text('Kameradan Fotoğraf Çek', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.cyanAccent),
              title: const Text('Galeriden Fotoğraf Seç', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.greenAccent),
              title: const Text('Metin Kutusu Ekle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addTextBox();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add, color: Colors.pinkAccent),
              title: const Text('Yeni Sayfa Ekle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addNewPage();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
      );
    }

    String modeName = currentToolMode == NotebookToolMode.panZoom
        ? 'Gezinme (Pan/Zoom)'
        : currentToolMode == NotebookToolMode.draw
            ? 'Çizim'
            : 'Düzenleme (Taşı/Boyutlandır)';
    Color modeColor = currentToolMode == NotebookToolMode.panZoom
        ? Colors.amberAccent
        : currentToolMode == NotebookToolMode.draw
            ? Colors.greenAccent
            : Colors.cyanAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.book.name, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
            Text('Mod: $modeName', style: TextStyle(fontSize: 11, color: modeColor)),
          ],
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          if (currentToolMode == NotebookToolMode.draw)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Geri Al',
              onPressed: _currentPage.strokes.isEmpty ? null : _undoLastStroke,
            ),
          IconButton(
            icon: Icon(
              currentToolMode == NotebookToolMode.panZoom
                  ? Icons.pan_tool
                  : currentToolMode == NotebookToolMode.draw
                      ? Icons.edit
                      : Icons.open_with,
              color: modeColor,
            ),
            tooltip: 'Modu Değiştir',
            onPressed: () {
              setState(() {
                if (currentToolMode == NotebookToolMode.panZoom) {
                  currentToolMode = NotebookToolMode.draw;
                } else if (currentToolMode == NotebookToolMode.draw) {
                  currentToolMode = NotebookToolMode.edit;
                } else {
                  currentToolMode = NotebookToolMode.panZoom;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Ekle',
            onPressed: _showAddSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E1E1E),
            onSelected: (val) {
              switch (val) {
                case 'settings':
                  _showSettingsDialog();
                  break;
                case 'clear':
                  _confirmClearPageDrawings();
                  break;
                case 'delete_page':
                  _confirmDeletePage();
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'settings', child: Text('Kalem/Silgi Ayarları', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'clear', child: Text('Sayfadaki Çizimleri Temizle', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'delete_page', child: Text('Sayfayı Sil', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        // Sayfa kaydırma (swipe) gesture'ı tamamen devre dışı bırakıldı.
        // Sayfalar arası geçiş yalnızca alt bardaki oklar veya sayfa menüsü ile yapılır.
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (idx) {
          setState(() {
            currentPageIndex = idx;
          });
          _resetToDefaultView();
        },
        itemCount: pages.length,
        itemBuilder: (context, pageIdx) {
          BookPageData page = pages[pageIdx];
          bool isEditMode = currentToolMode == NotebookToolMode.edit;

          Widget a4PageContent = Container(
            width: pageWidth,
            height: pageHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2),
              ],
            ),
            child: Stack(
              children: [
                // 1. ÖĞELER (Görseller ve Metinler - En Alt Katmanda)
                IgnorePointer(
                  ignoring: !isEditMode,
                  child: Stack(
                    children: [
                      for (int i = 0; i < page.items.length; i++)
                        Positioned(
                          left: page.items[i].x,
                          top: page.items[i].y,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              if (!page.items[i].locked) {
                                final currentScale = _transformationController.value.getMaxScaleOnAxis();
                                setState(() {
                                  page.items[i].x = (page.items[i].x + details.delta.dx / currentScale).clamp(0.0, pageWidth - 40);
                                  page.items[i].y = (page.items[i].y + details.delta.dy / currentScale).clamp(0.0, pageHeight - 40);
                                });
                              }
                            },
                            onPanEnd: (_) => _saveBookData(),
                            onDoubleTap: () {
                              if (page.items[i].type == 'text') {
                                _editTextBox(page.items[i]);
                              } else {
                                setState(() {
                                  page.items[i].locked = !page.items[i].locked;
                                });
                                _saveBookData();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: isEditMode
                                    ? Border.all(
                                        color: page.items[i].locked ? Colors.redAccent.withValues(alpha: 0.7) : Colors.blueAccent.withValues(alpha: 0.4),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (isEditMode)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(page.items[i].locked ? Icons.lock : Icons.lock_open, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() => page.items.removeAt(i));
                                                _saveBookData();
                                              },
                                              child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                            ),
                                          ],
                                        ),
                                      if (isEditMode) const SizedBox(height: 2),
                                      page.items[i].type == 'image'
                                          ? Image.file(
                                              File(page.items[i].content),
                                              width: page.items[i].width,
                                              fit: BoxFit.fitWidth,
                                              errorBuilder: (ctx, err, stack) => Container(
                                                width: 200,
                                                height: 200,
                                                color: Colors.grey.shade300,
                                                child: const Center(child: Text("Görsel Yüklenemedi")),
                                              ),
                                            )
                                          : ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 380),
                                              child: Text(
                                                page.items[i].content,
                                                softWrap: true,
                                                style: TextStyle(
                                                  color: Color(page.items[i].colorValue ?? Colors.black.toARGB32()),
                                                  fontWeight: page.items[i].bold ? FontWeight.bold : FontWeight.normal,
                                                  fontStyle: page.items[i].italic ? FontStyle.italic : FontStyle.normal,
                                                  decoration: TextDecoration.combine([
                                                    if (page.items[i].underline) TextDecoration.underline,
                                                    if (page.items[i].strike) TextDecoration.lineThrough,
                                                  ]),
                                                  fontSize: page.items[i].fontSize,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                  if (page.items[i].type == 'image' && !page.items[i].locked && isEditMode)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        onPanUpdate: (d) {
                                          final currentScale = _transformationController.value.getMaxScaleOnAxis();
                                          setState(() {
                                            page.items[i].width = (page.items[i].width + d.delta.dx / currentScale).clamp(80.0, pageWidth - page.items[i].x);
                                          });
                                        },
                                        onPanEnd: (_) => _saveBookData(),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          color: Colors.blueAccent,
                                          child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. ÇİZİMLER (Görsellerin Üzerinde)
                IgnorePointer(
                  child: CustomPaint(
                    painter: NotebookPainter(strokes: page.strokes),
                    size: Size.infinite,
                  ),
                ),

                // 3. YENİ ÇİZİM LİSTENER'I (Multi-touch / iki parmak korumalı)
                if (currentToolMode == NotebookToolMode.draw)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (details) {
                        _activePointers.add(details.pointer);
                        if (currentToolMode != NotebookToolMode.draw) return;

                        if (_activePointers.length > 1) {
                          _isMultiTouch = true;
                          if (!isEraser && page.strokes.isNotEmpty) {
                            setState(() {
                              page.strokes.removeLast();
                            });
                          }
                          return;
                        }

                        _isMultiTouch = false;
                        if (isEraser) {
                          _eraseAt(details.localPosition);
                        } else {
                          setState(() {
                            page.strokes.add(Stroke(
                              points: [{'dx': details.localPosition.dx, 'dy': details.localPosition.dy}],
                              colorValue: drawColor.toARGB32(),
                              width: strokeWidth,
                              opacity: strokeOpacity,
                            ));
                          });
                        }
                      },
                      onPointerMove: (details) {
                        if (currentToolMode != NotebookToolMode.draw) return;
                        
                        if (_isMultiTouch || _activePointers.length > 1) return;

                        if (isEraser) {
                          _eraseAt(details.localPosition);
                        } else if (page.strokes.isNotEmpty) {
                          setState(() {
                            page.strokes.last.points.add({
                              'dx': details.localPosition.dx,
                              'dy': details.localPosition.dy,
                            });
                          });
                        }
                      },
                      onPointerUp: (details) {
                        _activePointers.remove(details.pointer);
                        if (_activePointers.isEmpty) {
                          if (!_isMultiTouch && currentToolMode == NotebookToolMode.draw) {
                            _saveBookData();
                          }
                          _isMultiTouch = false;
                        }
                      },
                      onPointerCancel: (details) {
                        _activePointers.remove(details.pointer);
                        if (_activePointers.isEmpty) {
                          _isMultiTouch = false;
                        }
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
              ],
            ),
          );

          return Container(
            color: const Color(0xFF1E1E1E),
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false, 
              boundaryMargin: const EdgeInsets.all(1000), 
              minScale: 0.2,
              maxScale: 5.0,
              panEnabled: currentToolMode == NotebookToolMode.panZoom,
              scaleEnabled: true,
              child: a4PageContent,
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF1F1F1F),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in kPaletteColors) ...[
                      _toolBtn(c, () => setState(() {
                            drawColor = c;
                            isEraser = false;
                          })),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      icon: Icon(Icons.cleaning_services, color: isEraser ? Colors.cyanAccent : Colors.white54),
                      onPressed: () => setState(() => isEraser = true),
                      tooltip: "Silgi",
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              tooltip: "Önceki Sayfa",
              onPressed: currentPageIndex > 0
                  ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
            ),
            GestureDetector(
              onTap: _showPageJumpDialog,
              child: Text('${currentPageIndex + 1}/${pages.length}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              tooltip: "Sonraki Sayfa",
              onPressed: currentPageIndex < pages.length - 1
                  ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: drawColor == c && !isEraser ? Colors.white : Colors.transparent, width: 2)),
      ),
    );
  }
}

class NotebookPainter extends CustomPainter {
  final List<Stroke> strokes;

  NotebookPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      
      final paint = Paint()
        ..color = Color(stroke.colorValue).withValues(alpha: stroke.opacity)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round 
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width;

      if (stroke.points.length == 1) {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(stroke.points[0]['dx']!, stroke.points[0]['dy']!), stroke.width / 2, paint);
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points[0]['dx']!, stroke.points[0]['dy']!);
      
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i]['dx']!, stroke.points[i]['dy']!);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant NotebookPainter oldDelegate) => true;
}