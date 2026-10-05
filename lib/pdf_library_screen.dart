import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdfrx/pdfrx.dart';
import 'user_data_service.dart';

// --- ÇİZİM VE ŞEKİL MODELLERİ ---
enum DrawTool { pen, eraser, circle, rectangle, triangle }

class PdfDrawItem {
  int pageNumber;
  DrawTool tool;
  List<Offset> points; // Normalize koordinatlar (0.0 - 1.0)
  Color color;
  double strokeWidth;

  PdfDrawItem({
    required this.pageNumber,
    required this.tool,
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'tool': tool.toString(),
        'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.toARGB32(),
        'width': strokeWidth,
      };

  factory PdfDrawItem.fromJson(Map<String, dynamic> json) {
    var pList = json['points'] as List? ?? [];
    List<Offset> pts = pList.map((p) => Offset(p['dx']?.toDouble() ?? 0.0, p['dy']?.toDouble() ?? 0.0)).toList();
    
    DrawTool parsedTool = DrawTool.pen;
    String toolStr = json['tool'] ?? '';
    if (toolStr.contains('eraser')) parsedTool = DrawTool.eraser;
    if (toolStr.contains('circle')) parsedTool = DrawTool.circle;
    if (toolStr.contains('rectangle')) parsedTool = DrawTool.rectangle;
    if (toolStr.contains('triangle')) parsedTool = DrawTool.triangle;

    return PdfDrawItem(
      pageNumber: json['pageNumber'] ?? 1,
      tool: parsedTool,
      points: pts,
      color: Color(json['color'] ?? Colors.white.toARGB32()),
      strokeWidth: json['width']?.toDouble() ?? 4.0,
    );
  }
}

// --- PDF DOSYA VE DERS MODELLERİ ---
class PdfDoc {
  String id;
  String customName;
  String filePath;
  String coverType;
  Color coverColor;
  List<PdfDrawItem> drawings;
  Map<int, List<List<PdfDrawItem>>> pageNotes; // Her PDF sayfasına ait birden fazla A4 not sayfası

  PdfDoc({
    required this.id,
    required this.customName,
    required this.filePath,
    required this.coverType,
    required this.coverColor,
    required this.drawings,
    Map<int, List<List<PdfDrawItem>>>? pageNotes,
  }) : pageNotes = pageNotes ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'customName': customName,
        'filePath': filePath,
        'coverType': coverType,
        'coverColor': coverColor.toARGB32(),
        'drawings': drawings.map((d) => d.toJson()).toList(),
        'pageNotes': pageNotes.map((key, value) => MapEntry(
              key.toString(),
              value.map((pageDrawings) => pageDrawings.map((d) => d.toJson()).toList()).toList(),
            )),
      };

  factory PdfDoc.fromJson(Map<String, dynamic> json) {
    var dList = json['drawings'] as List? ?? [];
    
    Map<int, List<List<PdfDrawItem>>> loadedNotes = {};
    try {
      if (json['pageNotes'] != null) {
        Map<String, dynamic> notesMap = json['pageNotes'];
        notesMap.forEach((key, val) {
          int pageNum = int.tryParse(key) ?? 1;
          if (val is List) {
            if (val.isNotEmpty && val.first is List) {
              List<List<PdfDrawItem>> parsedPages = [];
              for (var pageData in val) {
                if (pageData is List) {
                  parsedPages.add(pageData.map((d) => PdfDrawItem.fromJson(d)).toList());
                }
              }
              loadedNotes[pageNum] = parsedPages;
            } else {
              List<PdfDrawItem> oldItems = val.map((d) => PdfDrawItem.fromJson(d)).toList();
              loadedNotes[pageNum] = [oldItems];
            }
          }
        });
      }
    } catch (_) {
      loadedNotes = {};
    }

    return PdfDoc(
      id: json['id'] ?? UniqueKey().toString(),
      customName: json['customName'] ?? 'Adsız PDF',
      filePath: json['filePath'] ?? '',
      coverType: json['coverType'] ?? 'color',
      coverColor: Color(json['coverColor'] ?? Colors.blueGrey.value),
      drawings: dList.map((d) => PdfDrawItem.fromJson(d)).toList(),
      pageNotes: loadedNotes,
    );
  }
}

class PdfSubject {
  String id;
  String name;
  Color color;
  List<PdfDoc> pdfs;

  PdfSubject({required this.id, required this.name, required this.color, required this.pdfs});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'pdfs': pdfs.map((p) => p.toJson()).toList(),
      };

  factory PdfSubject.fromJson(Map<String, dynamic> json) {
    var pList = json['pdfs'] as List? ?? [];
    return PdfSubject(
      id: json['id'] ?? UniqueKey().toString(),
      name: json['name'] ?? 'Yeni Ders',
      color: Color(json['color'] ?? Colors.teal.value),
      pdfs: pList.map((p) => PdfDoc.fromJson(p)).toList(),
    );
  }
}

// --- 1. DERSLER (ANA KÜTÜPHANE) EKRANI ---
class AdvancedPdfLibraryScreen extends StatefulWidget {
  const AdvancedPdfLibraryScreen({super.key});

  @override
  State<AdvancedPdfLibraryScreen> createState() => _AdvancedPdfLibraryScreenState();
}

class _AdvancedPdfLibraryScreenState extends State<AdvancedPdfLibraryScreen> {
  List<PdfSubject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allData = await UserDataService.fetchAllData();
      String? dataStr = allData['pdf_library_v2'];
      if (dataStr != null && dataStr.isNotEmpty) {
        List decoded = jsonDecode(dataStr);
        _subjects = decoded.map((e) => PdfSubject.fromJson(e)).toList();
      }
    } catch (e) {
      _subjects = [];
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    try {
      String encoded = jsonEncode(_subjects.map((e) => e.toJson()).toList());
      await UserDataService.saveModuleData('pdf_library_v2', encoded);
    } catch (_) {}
  }

  void _addSubjectDialog() {
    TextEditingController ctrl = TextEditingController();
    Color selectedColor = Colors.tealAccent;
    List<Color> colors = [Colors.tealAccent, Colors.blueAccent, Colors.purpleAccent, Colors.orangeAccent, Colors.pinkAccent];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Yeni Ders Klasörü', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Ders Adı (Örn: Matematik)', hintStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text("Klasör Rengi:", style: TextStyle(color: Colors.white70))),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: colors.map((c) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: CircleAvatar(
                      backgroundColor: c,
                      radius: 16,
                      child: selectedColor == c ? const Icon(Icons.check, color: Colors.black, size: 18) : null,
                    ),
                  );
                }).toList(),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: selectedColor, foregroundColor: Colors.black),
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() {
                    _subjects.add(PdfSubject(id: UniqueKey().toString(), name: ctrl.text.trim(), color: selectedColor, pdfs: []));
                    _saveData();
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSubject(PdfSubject subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Dersi Sil', style: TextStyle(color: Colors.white)),
        content: Text("'${subject.name}' dersini ve içindeki tüm PDF'leri silmek istediğine emin misin?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _subjects.remove(subject);
                _saveData();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('PDF Kütüphanesi'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: _subjects.isEmpty
          ? const Center(child: Text("Henüz ders klasörü oluşturmadın.", style: TextStyle(color: Colors.white54)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfListScreen(subject: subject, onSave: _saveData)))
                        .then((_) => setState(() {}));
                  },
                  onLongPress: () => _confirmDeleteSubject(subject),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: subject.color.withValues(alpha: 0.5), width: 2),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_copy_rounded, color: subject.color, size: 48),
                              const SizedBox(height: 12),
                              Text(subject.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${subject.pdfs.length} PDF', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => _confirmDeleteSubject(subject),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubjectDialog,
        backgroundColor: Colors.tealAccent,
        icon: const Icon(Icons.create_new_folder, color: Colors.black),
        label: const Text('Ders Ekle', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- 2. DERS İÇİ PDF LİSTESİ EKRANI ---
class PdfListScreen extends StatefulWidget {
  final PdfSubject subject;
  final VoidCallback onSave;

  const PdfListScreen({super.key, required this.subject, required this.onSave});

  @override
  State<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  
  void _addPdfDialog(String filePath, String originalName) {
    TextEditingController nameCtrl = TextEditingController(text: originalName.replaceAll('.pdf', ''));
    String coverType = 'color';
    Color coverColor = Colors.deepPurple;
    List<Color> coverColors = [Colors.deepPurple, Colors.brown, Colors.indigo, Colors.teal, Colors.blueGrey];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("PDF'i İsimlendir ve Kapak Seç", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "PDF İsmi (Zorunlu)", labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 24),
                const Text("Kapak Türü:", style: TextStyle(color: Colors.white70)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text("İlk Sayfa", style: TextStyle(color: Colors.white, fontSize: 13)),
                        value: 'first_page',
                        groupValue: coverType,
                        activeColor: widget.subject.color,
                        onChanged: (v) => setModalState(() => coverType = v!),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text("Renkli Kapak", style: TextStyle(color: Colors.white, fontSize: 13)),
                        value: 'color',
                        groupValue: coverType,
                        activeColor: widget.subject.color,
                        onChanged: (v) => setModalState(() => coverType = v!),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (coverType == 'color') ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: coverColors.map((c) {
                      return GestureDetector(
                        onTap: () => setModalState(() => coverColor = c),
                        child: Container(
                          width: 40,
                          height: 56,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: coverColor == c ? Colors.white : Colors.transparent, width: 2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: widget.subject.color, minimumSize: const Size(double.infinity, 50)),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen PDF ismini girin!')));
                      return;
                    }
                    setState(() {
                      widget.subject.pdfs.add(PdfDoc(
                        id: UniqueKey().toString(),
                        customName: nameCtrl.text.trim(),
                        filePath: filePath,
                        coverType: coverType,
                        coverColor: coverColor,
                        drawings: [],
                      ));
                      widget.onSave();
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("PDF'i Kaydet", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickPdf() async {
    try {
      const XTypeGroup pdfGroup = XTypeGroup(
        label: 'PDFs',
        extensions: <String>['pdf'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[pdfGroup]);
      
      if (file != null) {
        _addPdfDialog(file.path, file.name);
      }
    } catch (e) {
      _addPdfDialog("sample.pdf", "Örnek Ders Notu.pdf");
    }
  }

  void _confirmDeletePdf(PdfDoc pdf) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("PDF'i Sil", style: TextStyle(color: Colors.white)),
        content: Text("'${pdf.customName}' adlı PDF'i silmek istediğine emin misin?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("İptal", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                widget.subject.pdfs.remove(pdf);
                widget.onSave();
              });
              Navigator.pop(c);
            },
            child: const Text("Sil", style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text('${widget.subject.name} Notları'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: widget.subject.pdfs.isEmpty
          ? const Center(child: Text("Bu derse henüz PDF eklenmedi.", style: TextStyle(color: Colors.white54)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 24,
                childAspectRatio: 0.65,
              ),
              itemCount: widget.subject.pdfs.length,
              itemBuilder: (context, index) {
                final pdf = widget.subject.pdfs[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerEditorScreen(pdf: pdf, onSave: widget.onSave)))
                        .then((_) => setState(() {}));
                  },
                  onLongPress: () => _confirmDeletePdf(pdf),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: pdf.coverType == 'color' ? pdf.coverColor : Colors.white,
                                borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                                border: Border(left: BorderSide(color: Colors.black.withValues(alpha: 0.3), width: 4)),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(2, 2))],
                              ),
                              child: pdf.coverType == 'first_page'
                                  ? const Center(child: Icon(Icons.picture_as_pdf, color: Colors.black12, size: 40))
                                  : Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Text(pdf.customName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: InkWell(
                                onTap: () => _confirmDeletePdf(pdf),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(pdf.customName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickPdf,
        backgroundColor: widget.subject.color,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

// --- 3. GERÇEK PDF GÖRÜNTÜLEYİCİ VE ÇİZİM EDİTÖRÜ ---
class PdfViewerEditorScreen extends StatefulWidget {
  final PdfDoc pdf;
  final VoidCallback onSave;

  const PdfViewerEditorScreen({super.key, required this.pdf, required this.onSave});

  @override
  State<PdfViewerEditorScreen> createState() => _PdfViewerEditorScreenState();
}

class _PdfViewerEditorScreenState extends State<PdfViewerEditorScreen> {
  late List<PdfDrawItem> _drawings;
  
  DrawTool _activeTool = DrawTool.pen;
  Color _activeColor = Colors.redAccent;
  double _strokeWidth = 4.0;
  bool _isPanZoomMode = true;

  final PdfViewerController _pdfController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 1;
  final TextEditingController _pageInputController = TextEditingController();

  final List<Color> _penColors = [Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.yellowAccent, Colors.white];

  @override
  void initState() {
    super.initState();
    _drawings = List.from(widget.pdf.drawings);
  }

  @override
  void dispose() {
    _pageInputController.dispose();
    super.dispose();
  }

  void _autoSave() {
    widget.pdf.drawings = _drawings;
    widget.onSave();
  }

  void _undo() {
    if (_drawings.isNotEmpty) {
      setState(() {
        _drawings.removeLast();
        _autoSave();
      });
    }
  }

  void _goToPage(String value) {
    int? targetPage = int.tryParse(value);
    if (targetPage != null) {
      if (targetPage < 1) targetPage = 1;
      if (targetPage > _totalPages) targetPage = _totalPages;
      
      _pdfController.goToPage(pageNumber: targetPage);
      FocusScope.of(context).unfocus();
    }
  }

  void _eraseAtPdf(Offset localPosition, double pageW, double pageH, int pageNum) {
    setState(() {
      _drawings.removeWhere((item) {
        if (item.pageNumber != pageNum) return false;
        if (item.points.isEmpty) return false;
        if (item.tool == DrawTool.pen || item.tool == DrawTool.eraser) {
          for (var p in item.points) {
            Offset itemPos = Offset(p.dx * pageW, p.dy * pageH);
            if ((itemPos - localPosition).distance < 30.0) {
              return true;
            }
          }
        } else {
          if (item.points.length >= 2) {
            Offset p1 = Offset(item.points.first.dx * pageW, item.points.first.dy * pageH);
            Offset p2 = Offset(item.points.last.dx * pageW, item.points.last.dy * pageH);
            Rect rect = Rect.fromPoints(p1, p2);
            if (rect.inflate(20).contains(localPosition)) {
              return true;
            }
          }
        }
        return false;
      });
      _autoSave();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isRealFile = widget.pdf.filePath.isNotEmpty && File(widget.pdf.filePath).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.pdf.customName, style: const TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.undo, color: Colors.white70, size: 20), onPressed: _undo, tooltip: 'Geri Al'),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1F1F1F),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _toolBtn(Icons.pan_tool_rounded, 'Kaydır/Zoom', _isPanZoomMode, () => setState(() => _isPanZoomMode = true)),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.edit, 'Kalem', !_isPanZoomMode && _activeTool == DrawTool.pen, () => setState(() { _isPanZoomMode = false; _activeTool = DrawTool.pen; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.cleaning_services_rounded, 'Silgi', !_isPanZoomMode && _activeTool == DrawTool.eraser, () => setState(() { _isPanZoomMode = false; _activeTool = DrawTool.eraser; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.circle_outlined, 'Daire', !_isPanZoomMode && _activeTool == DrawTool.circle, () => setState(() { _isPanZoomMode = false; _activeTool = DrawTool.circle; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.crop_square, 'Kare', !_isPanZoomMode && _activeTool == DrawTool.rectangle, () => setState(() { _isPanZoomMode = false; _activeTool = DrawTool.rectangle; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.change_history, 'Üçgen', !_isPanZoomMode && _activeTool == DrawTool.triangle, () => setState(() { _isPanZoomMode = false; _activeTool = DrawTool.triangle; })),
                  
                  const VerticalDivider(color: Colors.white24, thickness: 1, indent: 8, endIndent: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, color: Colors.tealAccent, size: 14),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 32,
                          height: 24,
                          child: TextField(
                            controller: _pageInputController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '$_currentPage',
                              hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              contentPadding: const EdgeInsets.only(bottom: 12),
                              border: InputBorder.none,
                            ),
                            onSubmitted: _goToPage,
                          ),
                        ),
                        Text('/$_totalPages', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),

                  const VerticalDivider(color: Colors.white24, thickness: 1, indent: 8, endIndent: 8),

                  ..._penColors.map((c) => GestureDetector(
                        onTap: () => setState(() => _activeColor = c),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 20, height: 20,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _activeColor == c ? Colors.tealAccent : Colors.transparent, width: 2)),
                        ),
                      )),

                  const VerticalDivider(color: Colors.white24, thickness: 1, indent: 8, endIndent: 8),

                  Text('${_strokeWidth.toInt()}px', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  SizedBox(
                    width: 80,
                    child: Slider(
                      value: _strokeWidth, min: 1, max: 15, activeColor: Colors.tealAccent,
                      onChanged: (v) => setState(() => _strokeWidth = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: isRealFile
                ? PdfViewer.file(
                    widget.pdf.filePath,
                    controller: _pdfController,
                    params: PdfViewerParams(
                      panEnabled: true,
                      scaleEnabled: true,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page ?? 1;
                        });
                      },
                      onDocumentChanged: (document) {
                        if (document != null) {
                          setState(() {
                            _totalPages = document.pages.length;
                          });
                        }
                      },
                      pageOverlaysBuilder: (context, pageRect, page) {
                        int pageNum = page.pageNumber;
                        List<PdfDrawItem> pageDrawings = _drawings.where((d) => d.pageNumber == pageNum).toList();

                        return [
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: _isPanZoomMode,
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    painter: PagePdfPainter(
                                      drawings: pageDrawings,
                                      pageWidth: page.width,
                                      pageHeight: page.height,
                                    ),
                                    size: Size.infinite,
                                  ),
                                  if (!_isPanZoomMode)
                                    GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onPanStart: (details) {
                                        if (_activeTool == DrawTool.eraser) {
                                          _eraseAtPdf(details.localPosition, pageRect.width, pageRect.height, pageNum);
                                        } else {
                                          setState(() {
                                            double normX = details.localPosition.dx / pageRect.width;
                                            double normY = details.localPosition.dy / pageRect.height;
                                            _drawings.add(PdfDrawItem(
                                              pageNumber: pageNum,
                                              tool: _activeTool,
                                              points: [Offset(normX, normY)],
                                              color: _activeColor,
                                              strokeWidth: _strokeWidth,
                                            ));
                                          });
                                        }
                                      },
                                      onPanUpdate: (details) {
                                        if (_activeTool == DrawTool.eraser) {
                                          _eraseAtPdf(details.localPosition, pageRect.width, pageRect.height, pageNum);
                                        } else {
                                          setState(() {
                                            if (_drawings.isNotEmpty) {
                                              var lastItem = _drawings.last;
                                              if (lastItem.pageNumber == pageNum) {
                                                double normX = details.localPosition.dx / pageRect.width;
                                                double normY = details.localPosition.dy / pageRect.height;
                                                if (_activeTool == DrawTool.pen) {
                                                  lastItem.points.add(Offset(normX, normY));
                                                } else {
                                                  if (lastItem.points.length == 1) {
                                                    lastItem.points.add(Offset(normX, normY));
                                                  } else {
                                                    lastItem.points[1] = Offset(normX, normY);
                                                  }
                                                }
                                              }
                                            }
                                          });
                                        }
                                      },
                                      onPanEnd: (details) {
                                        _autoSave();
                                      },
                                      child: Container(color: Colors.transparent),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            top: 8,
                            right: 8,
                            child: IgnorePointer(
                              ignoring: false,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PageNotesScreen(
                                        pdfDoc: widget.pdf,
                                        pageNumber: pageNum,
                                        onSave: widget.onSave,
                                      ),
                                    ),
                                  ).then((_) => setState(() {}));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.tealAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(1, 1))],
                                  ),
                                  child: const Icon(Icons.add, color: Colors.black, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                    ),
                  )
                : const Center(
                    child: Text("Gerçek PDF dosyası bulunamadı.", style: TextStyle(color: Colors.white54)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.tealAccent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? Colors.tealAccent : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.tealAccent : Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- 4. HER SAYFAYA ÖZEL SAMAN SARISI KILAVUZ ÇİZGİLİ A4 NOT EKRANI ---
class PageNotesScreen extends StatefulWidget {
  final PdfDoc pdfDoc;
  final int pageNumber;
  final VoidCallback onSave;

  const PageNotesScreen({super.key, required this.pdfDoc, required this.pageNumber, required this.onSave});

  @override
  State<PageNotesScreen> createState() => _PageNotesScreenState();
}

class _PageNotesScreenState extends State<PageNotesScreen> {
  late List<List<PdfDrawItem>> _notePages;
  DrawTool _activeTool = DrawTool.pen;
  Color _activeColor = Colors.teal;
  double _strokeWidth = 4.0;
  bool _isScrollMode = true;

  final List<Color> _penColors = [Colors.teal, Colors.redAccent, Colors.blueAccent, Colors.black, Colors.purple];

  @override
  void initState() {
    super.initState();
    if (widget.pdfDoc.pageNotes.containsKey(widget.pageNumber) && widget.pdfDoc.pageNotes[widget.pageNumber]!.isNotEmpty) {
      _notePages = List.from(widget.pdfDoc.pageNotes[widget.pageNumber]!.map((page) => List<PdfDrawItem>.from(page)));
    } else {
      _notePages = [[]];
    }
  }

  void _autoSave() {
    widget.pdfDoc.pageNotes[widget.pageNumber] = _notePages;
    widget.onSave();
  }

  void _undo(int pageIndex) {
    if (_notePages[pageIndex].isNotEmpty) {
      setState(() {
        _notePages[pageIndex].removeLast();
        _autoSave();
      });
    }
  }

  void _deletePage(int pageIndex) {
    if (_notePages.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Sayfayı Sil', style: TextStyle(color: Colors.white)),
          content: Text('Sayfa ${pageIndex + 1} silinsin mi?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _notePages.removeAt(pageIndex);
                  _autoSave();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Sayfayı Temizle', style: TextStyle(color: Colors.white)),
          content: const Text('Tek kalan sayfa silinemez ancak içeriği temizlenebilir. Temizlensin mi?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _notePages[0].clear();
                  _autoSave();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Temizle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _addNewPage() {
    setState(() {
      _notePages.add([]);
      _autoSave();
    });
  }

  void _eraseAt(Offset localPosition, int pIndex) {
    setState(() {
      _notePages[pIndex].removeWhere((item) {
        if (item.points.isEmpty) return false;
        if (item.tool == DrawTool.pen || item.tool == DrawTool.eraser) {
          for (var p in item.points) {
            Offset itemPos = Offset(p.dx * 600, p.dy * 848);
            if ((itemPos - localPosition).distance < 30.0) {
              return true;
            }
          }
        } else {
          if (item.points.length >= 2) {
            Offset p1 = Offset(item.points.first.dx * 600, item.points.first.dy * 848);
            Offset p2 = Offset(item.points.last.dx * 600, item.points.last.dy * 848);
            Rect rect = Rect.fromPoints(p1, p2);
            if (rect.inflate(20).contains(localPosition)) {
              return true;
            }
          }
        }
        return false;
      });
      _autoSave();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('${widget.pdfDoc.customName} - Sayfa ${widget.pageNumber} Notları', style: const TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1F1F1F),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _toolBtn(Icons.swap_vert, 'Kaydır', _isScrollMode, () => setState(() => _isScrollMode = true)),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.edit, 'Kalem', !_isScrollMode && _activeTool == DrawTool.pen, () => setState(() { _isScrollMode = false; _activeTool = DrawTool.pen; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.cleaning_services_rounded, 'Silgi', !_isScrollMode && _activeTool == DrawTool.eraser, () => setState(() { _isScrollMode = false; _activeTool = DrawTool.eraser; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.circle_outlined, 'Daire', !_isScrollMode && _activeTool == DrawTool.circle, () => setState(() { _isScrollMode = false; _activeTool = DrawTool.circle; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.crop_square, 'Kare', !_isScrollMode && _activeTool == DrawTool.rectangle, () => setState(() { _isScrollMode = false; _activeTool = DrawTool.rectangle; })),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.change_history, 'Üçgen', !_isScrollMode && _activeTool == DrawTool.triangle, () => setState(() { _isScrollMode = false; _activeTool = DrawTool.triangle; })),
                  
                  const VerticalDivider(color: Colors.white24, thickness: 1, indent: 8, endIndent: 8),

                  ..._penColors.map((c) => GestureDetector(
                        onTap: () => setState(() => _activeColor = c),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 20, height: 20,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _activeColor == c ? Colors.white : Colors.transparent, width: 2)),
                        ),
                      )),

                  const VerticalDivider(color: Colors.white24, thickness: 1, indent: 8, endIndent: 8),

                  Text('${_strokeWidth.toInt()}px', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  SizedBox(
                    width: 80,
                    child: Slider(
                      value: _strokeWidth, min: 1, max: 15, activeColor: Colors.tealAccent,
                      onChanged: (v) => setState(() => _strokeWidth = v),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              physics: _isScrollMode ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              itemCount: _notePages.length + 1,
              itemBuilder: (context, index) {
                if (index == _notePages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 40),
                    child: Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: _addNewPage,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Yeni Sayfa Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }

                int pIndex = index;
                return Center(
                  child: Container(
                    width: 600,
                    height: 848,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4ECD8),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(2, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: NotebookPagePainter(drawings: _notePages[pIndex]),
                            size: Size.infinite,
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) {
                              if (_isScrollMode) return;
                              if (_activeTool == DrawTool.eraser) {
                                _eraseAt(details.localPosition, pIndex);
                              } else {
                                setState(() {
                                  double normX = details.localPosition.dx / 600;
                                  double normY = details.localPosition.dy / 848;
                                  _notePages[pIndex].add(PdfDrawItem(
                                    pageNumber: widget.pageNumber,
                                    tool: _activeTool,
                                    points: [Offset(normX, normY)],
                                    color: _activeColor,
                                    strokeWidth: _strokeWidth,
                                  ));
                                });
                              }
                            },
                            onPanUpdate: (details) {
                              if (_isScrollMode) return;
                              if (_activeTool == DrawTool.eraser) {
                                _eraseAt(details.localPosition, pIndex);
                              } else {
                                setState(() {
                                  if (_notePages[pIndex].isNotEmpty) {
                                    var last = _notePages[pIndex].last;
                                    double normX = details.localPosition.dx / 600;
                                    double normY = details.localPosition.dy / 848;
                                    if (_activeTool == DrawTool.pen) {
                                      last.points.add(Offset(normX, normY));
                                    } else {
                                      if (last.points.length == 1) {
                                        last.points.add(Offset(normX, normY));
                                      } else {
                                        last.points[1] = Offset(normX, normY);
                                      }
                                    }
                                  }
                                });
                              }
                            },
                            onPanEnd: (details) {
                              if (!_isScrollMode) {
                                _autoSave();
                              }
                            },
                            child: Container(color: Colors.transparent),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Row(
                              children: [
                                Text('Sayfa ${pIndex + 1}', style: TextStyle(color: Colors.brown.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _undo(pIndex),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Colors.brown.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.undo, color: Colors.brown, size: 16),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _deletePage(pIndex),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.tealAccent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? Colors.tealAccent : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.tealAccent : Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class PagePdfPainter extends CustomPainter {
  final List<PdfDrawItem> drawings;
  final double pageWidth;
  final double pageHeight;

  PagePdfPainter({required this.drawings, required this.pageWidth, required this.pageHeight});

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / pageWidth;

    for (var item in drawings) {
      if (item.points.isEmpty) continue;

      Paint paint = Paint()
        ..color = item.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.strokeWidth * scale;

      List<Offset> scaledPoints = item.points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

      if (item.tool == DrawTool.pen || item.tool == DrawTool.eraser) {
        for (int i = 0; i < scaledPoints.length - 1; i++) {
          canvas.drawLine(scaledPoints[i], scaledPoints[i + 1], paint);
        }
      } else if (scaledPoints.length >= 2) {
        Offset p1 = scaledPoints.first;
        Offset p2 = scaledPoints.last;
        Rect rect = Rect.fromPoints(p1, p2);

        if (item.tool == DrawTool.circle) {
          canvas.drawOval(rect, paint);
        } else if (item.tool == DrawTool.rectangle) {
          canvas.drawRect(rect, paint);
        } else if (item.tool == DrawTool.triangle) {
          Path path = Path();
          path.moveTo(rect.center.dx, rect.top);
          path.lineTo(rect.right, rect.bottom);
          path.lineTo(rect.left, rect.bottom);
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NotebookPagePainter extends CustomPainter {
  final List<PdfDrawItem> drawings;
  NotebookPagePainter({required this.drawings});

  @override
  void paint(Canvas canvas, Size size) {
    Paint linePaint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    double lineHeight = 35.0;
    for (double y = 60.0; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(50, y), Offset(size.width - 20, y), linePaint);
    }

    Paint marginPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(50, 0), Offset(50, size.height), marginPaint);

    for (var item in drawings) {
      if (item.points.isEmpty) continue;

      Paint paint = Paint()
        ..color = item.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.strokeWidth;

      List<Offset> pts = item.points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

      if (item.tool == DrawTool.pen || item.tool == DrawTool.eraser) {
        for (int i = 0; i < pts.length - 1; i++) {
          canvas.drawLine(pts[i], pts[i + 1], paint);
        }
      } else if (pts.length >= 2) {
        Offset p1 = pts.first;
        Offset p2 = pts.last;
        Rect rect = Rect.fromPoints(p1, p2);

        if (item.tool == DrawTool.circle) {
          canvas.drawOval(rect, paint);
        } else if (item.tool == DrawTool.rectangle) {
          canvas.drawRect(rect, paint);
        } else if (item.tool == DrawTool.triangle) {
          Path path = Path();
          path.moveTo(rect.center.dx, rect.top);
          path.lineTo(rect.right, rect.bottom);
          path.lineTo(rect.left, rect.bottom);
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}