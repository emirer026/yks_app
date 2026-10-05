import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'user_data_service.dart';

class StickyNoteData {
  String id;
  Offset position;
  Color paperColor;
  Color pinColor;
  double rotation;
  double scale;
  double width;
  double height;
  List<DrawingPoint?> points;
  
  String? text;
  double? textFontSize;
  FontWeight? textFontWeight;
  String? assetPath;
  bool isProtected;
  bool isLocked;

  // Çizim performansını anlık (0 gecikme) kılmak için ValueNotifier
  late ValueNotifier<List<DrawingPoint?>> pointsNotifier;
  // Çoklu dokunma (2 parmak zoom/pan) anında çizimi engellemek için parmak takip seti
  final Set<int> activePointers = {};

  StickyNoteData({
    required this.id,
    required this.position,
    required this.paperColor,
    required this.pinColor,
    required this.rotation,
    this.scale = 1.0,
    this.width = 220.0,
    this.height = 220.0,
    required this.points,
    this.text,
    this.textFontSize,
    this.textFontWeight,
    this.assetPath,
    this.isProtected = false,
    this.isLocked = true,
  }) {
    pointsNotifier = ValueNotifier<List<DrawingPoint?>>(List.from(points));
  }
}

class DrawingPoint {
  Offset point;
  Paint paint;
  DrawingPoint({required this.point, required this.paint});
}

class CorkboardProject {
  String title;
  List<StickyNoteData> notes;
  CorkboardProject({required this.title, required this.notes});
}

class CorkboardScreen extends StatefulWidget {
  const CorkboardScreen({super.key});

  @override
  State<CorkboardScreen> createState() => _CorkboardScreenState();
}

class _CorkboardScreenState extends State<CorkboardScreen> with SingleTickerProviderStateMixin {
  List<CorkboardProject> _boards = [_ataturkKosesi];
  int _currentBoardIndex = 0;

  final TransformationController _transformationController = TransformationController();

  // Raptiye varsayılan olarak otomatik seçili başlar
  Color? _selectedPinColor = Colors.red;
  String _selectedTool = 'hand'; 
  
  Color _selectedPenColor = Colors.black;
  double _penStrokeWidth = 3.0;
  double _penOpacity = 1.0;
  double _penHue = 0.0;
  double _eraserSize = 20.0;

  double _defaultNoteScale = 1.0;
  double _paperHue = 50.0;
  Color _customPaperColor = Colors.yellow.shade100;

  final double worldWidth = 7000.0;
  final double worldHeight = 4200.0;
  final double frameBorder = 40.0;
  final double defaultNoteSize = 360.0;
  final double overflowAllowance = 60.0;

  final List<Color> _pinColors = [
    Colors.red,
    Colors.blueAccent,
    Colors.amber,
    Colors.deepPurple,
  ];

  List<StickyNoteData> get _currentNotes => _boards[_currentBoardIndex].notes;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Atatürk Köşesi Projesi
  static CorkboardProject get _ataturkKosesi {
    return CorkboardProject(
      title: 'Atatürk Köşesi',
      notes: [
        StickyNoteData(
          id: 'p1', position: const Offset(700, 750), paperColor: Colors.white, pinColor: Colors.red, rotation: -0.04, width: 520, height: 640, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/1.jpg',
        ),
        StickyNoteData(
          id: 'p2', position: const Offset(1300, 770), paperColor: Colors.white, pinColor: Colors.blueAccent, rotation: 0.03, width: 540, height: 500, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/2.jpg',
        ),
        StickyNoteData(
          id: 'ata_dogum', position: const Offset(1900, 750), paperColor: Colors.yellow.shade100, pinColor: Colors.amber, rotation: -0.02, width: 540, height: 520, points: [], isProtected: true, isLocked: true,
          text: "DOĞUM YERİ VE AİLESİ\n\n1881 yılında Selanik'te doğdu.\n\nAnnesi: Zübeyde Hanım\nBabası: Ali Rıza Efendi\nKardeşi: Makbule Hanım\n\nÇocukluk yıllarından itibaren liderlik vasıflarıyla öne çıkmıştır.",
          textFontSize: 19, textFontWeight: FontWeight.w600,
        ),
        StickyNoteData(
          id: 'p3', position: const Offset(2500, 760), paperColor: Colors.white, pinColor: Colors.deepPurple, rotation: 0.02, width: 520, height: 480, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/3.jpg',
        ),
        StickyNoteData(
          id: 'p4', position: const Offset(3100, 750), paperColor: Colors.white, pinColor: Colors.red, rotation: -0.03, width: 500, height: 460, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/4.jpg',
        ),
        StickyNoteData(
          id: 'ata_okul', position: const Offset(3660, 750), paperColor: Colors.orange.shade100, pinColor: Colors.blueAccent, rotation: 0.02, width: 540, height: 520, points: [], isProtected: true, isLocked: true,
          text: "OKUDUĞU OKULLAR\n\n• Mahalle Mektebi & Şemsi Efendi\n• Selanik Mülkiye ve Askeri Rüştiyesi\n• Manastır Askeri İdadisi\n• İstanbul Harp Okulu\n• İstanbul Harp Akademisi (Kurmay Yüzbaşı)",
          textFontSize: 18, textFontWeight: FontWeight.w600,
        ),
        StickyNoteData(
          id: 'p5', position: const Offset(4260, 770), paperColor: Colors.white, pinColor: Colors.amber, rotation: -0.01, width: 500, height: 480, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/5.jpg',
        ),
        StickyNoteData(
          id: 'p6', position: const Offset(4820, 780), paperColor: Colors.white, pinColor: Colors.deepPurple, rotation: 0.03, width: 500, height: 440, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/6.jpg',
        ),
        StickyNoteData(
          id: 'p7', position: const Offset(5380, 770), paperColor: Colors.white, pinColor: Colors.red, rotation: -0.02, width: 500, height: 440, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/7.jpg',
        ),
        StickyNoteData(
          id: 'p8', position: const Offset(5940, 760), paperColor: Colors.white, pinColor: Colors.blueAccent, rotation: 0.02, width: 500, height: 450, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/8.jpg',
        ),
        StickyNoteData(
          id: 'p9', position: const Offset(700, 1500), paperColor: Colors.white, pinColor: Colors.amber, rotation: 0.02, width: 500, height: 450, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/9.jpg',
        ),
        StickyNoteData(
          id: 'p10', position: const Offset(1260, 1460), paperColor: Colors.white, pinColor: Colors.deepPurple, rotation: -0.03, width: 440, height: 580, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/10.jpg',
        ),
        StickyNoteData(
          id: 'p11', position: const Offset(1760, 1510), paperColor: Colors.white, pinColor: Colors.red, rotation: 0.03, width: 500, height: 440, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/11.jpg',
        ),
        StickyNoteData(
          id: 'ata_kitaplar', position: const Offset(2320, 1480), paperColor: Colors.green.shade100, pinColor: Colors.blueAccent, rotation: -0.02, width: 540, height: 520, points: [], isProtected: true, isLocked: true,
          text: "YAZDIĞI ESERLER VE KİTAPLAR\n\n• Nutuk (1927)\n• Geometri Kitabı (1937)\n• Zabit ve Kumandan ile Hasbihal\n• Taktik Tatbikat Gezisi\n• Medeni Bilgiler",
          textFontSize: 18, textFontWeight: FontWeight.w600,
        ),
        StickyNoteData(
          id: 'p12', position: const Offset(2920, 1460), paperColor: Colors.white, pinColor: Colors.amber, rotation: 0.01, width: 450, height: 580, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/12.jpg',
        ),
        StickyNoteData(
          id: 'p13', position: const Offset(3430, 1500), paperColor: Colors.white, pinColor: Colors.deepPurple, rotation: -0.02, width: 500, height: 460, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/13.jpg',
        ),
        StickyNoteData(
          id: 'ata_sozler', position: const Offset(3990, 1480), paperColor: Colors.yellow.shade100, pinColor: Colors.red, rotation: 0.02, width: 580, height: 520, points: [], isProtected: true, isLocked: true,
          text: "UNUTULMAZ SÖZLERİ\n\n• 'Yurtta sulh, cihanda sulh.'\n• 'Hayatta en hakiki mürşit ilimdir.'\n• 'Egemenlik kayıtsız şartsız milletindir.'\n• 'Ne mutlu Türküm diyene!'\n• 'Benim naçiz vücudum elbet toprak olacaktır.'",
          textFontSize: 18, textFontWeight: FontWeight.w600,
        ),
        StickyNoteData(
          id: 'p14', position: const Offset(4630, 1500), paperColor: Colors.white, pinColor: Colors.blueAccent, rotation: -0.03, width: 500, height: 460, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/14.jpg',
        ),
        StickyNoteData(
          id: 'p15', position: const Offset(5190, 1500), paperColor: Colors.white, pinColor: Colors.amber, rotation: 0.02, width: 500, height: 460, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/15.jpg',
        ),
        StickyNoteData(
          id: 'p16', position: const Offset(5750, 1460), paperColor: Colors.white, pinColor: Colors.deepPurple, rotation: -0.01, width: 440, height: 580, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/16.jpg',
        ),
        StickyNoteData(
          id: 'p17', position: const Offset(700, 2250), paperColor: Colors.white, pinColor: Colors.red, rotation: 0.03, width: 500, height: 460, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/17.jpg',
        ),
        StickyNoteData(
          id: 'p18', position: const Offset(1260, 2260), paperColor: Colors.white, pinColor: Colors.blueAccent, rotation: -0.02, width: 480, height: 440, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/18.jpg',
        ),
        StickyNoteData(
          id: 'ata_cephe', position: const Offset(1800, 2240), paperColor: Colors.green.shade100, pinColor: Colors.amber, rotation: 0.01, width: 580, height: 540, points: [], isProtected: true, isLocked: true,
          text: "GÖREV ALDIĞI CEPHELER\n\n1. Trablusgarp Savaşı (Derne, Tobruk)\n2. Balkan Savaşları\n3. Çanakkale Cephesi ('Ben size taarruzu değil, ölmeyi emrediyorum!')\n4. Kafkas Cephesi (Muş, Bitlis)\n5. Suriye-Filistin Cephesi\n6. Kurtuluş Savaşı - Başkomutanlık",
          textFontSize: 18, textFontWeight: FontWeight.w600,
        ),
        StickyNoteData(
          id: 'p19', position: const Offset(2440, 2230), paperColor: Colors.white, pinColor: Colors.deepPurple, rotation: -0.03, width: 450, height: 580, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/19.jpg',
        ),
        StickyNoteData(
          id: 'ata_ilkeler', position: const Offset(2950, 2240), paperColor: Colors.yellow.shade100, pinColor: Colors.red, rotation: 0.02, width: 580, height: 540, points: [], isProtected: true, isLocked: true,
          text: "ATATÜRK İLKELERİ\n\n• Cumhuriyetçilik\n• Milliyetçilik\n• Halkçılık\n• Devletçilik\n• Laiklik\n• İnkılapçılık\n\nTürkiye Cumhuriyeti'nin sarsılmaz temel taşlarıdır.",
          textFontSize: 18, textFontWeight: FontWeight.w600,
        ),
        StickyNoteData(
          id: 'ata_hitabe', position: const Offset(3590, 2220), paperColor: Colors.orange.shade100, pinColor: Colors.blueAccent, rotation: -0.01, width: 1080, height: 700, points: [], isProtected: true, isLocked: true,
          text: "GENÇLİĞE HİTABE\n\nEy Türk gençliği! Birinci vazifen; Türk istiklalini, Türk cumhuriyetini, ilelebet muhafaza ve müdafaa etmektir.\n\nMevcudiyetinin ve istikbalinin yegâne temeli budur. Bu temel, senin en kıymetli hazinendir. İstikbalde dahi seni bu hazineden mahrum etmek isteyecek dâhilî ve haricî bedhahların olacaktır. Bir gün, istiklal ve cumhuriyeti müdafaa mecburiyetine düşersen, vazifeye atılmak için içinde bulunacağın vaziyetin imkân ve şeraitini düşünmeyeceksin!\n\nEy Türk istikbalinin evladı! İşte, bu ahval ve şerait içinde dahi vazifen, Türk istiklal ve cumhuriyetini kurtarmaktır. Muhtaç olduğun kudret, damarlarındaki asil kanda mevcuttur!",
          textFontSize: 20, textFontWeight: FontWeight.w700,
        ),
        StickyNoteData(
          id: 'p20', position: const Offset(4740, 2260), paperColor: Colors.white, pinColor: Colors.amber, rotation: 0.03, width: 520, height: 440, points: [], isProtected: true, isLocked: true,
          assetPath: 'assets/images/20.jpg',
        ),
      ],
    );
  }

  Future<void> _saveData() async {
    final List<Map<String, dynamic>> boardsJson = _boards.map((board) {
      return {
        'title': board.title,
        'notes': board.notes.map((note) {
          return {
            'id': note.id,
            'dx': note.position.dx,
            'dy': note.position.dy,
            'paperColor': note.paperColor.toARGB32(),
            'pinColor': note.pinColor.toARGB32(),
            'rotation': note.rotation,
            'scale': note.scale,
            'width': note.width,
            'height': note.height,
            'text': note.text,
            'textFontSize': note.textFontSize,
            'assetPath': note.assetPath,
            'isProtected': note.isProtected,
            'isLocked': note.isLocked,
            'points': note.points.map((p) {
              if (p == null) return {'isEnd': true};
              return {
                'x': p.point.dx,
                'y': p.point.dy,
                'color': p.paint.color.toARGB32(),
                'width': p.paint.strokeWidth,
              };
            }).toList(),
          };
        }).toList(),
      };
    }).toList();

    await UserDataService.saveModuleData('corkboard', jsonEncode(boardsJson));
  }

  Future<void> _loadData() async {
    try {
      final allData = await UserDataService.fetchAllData();
      final String? dataStr = allData['corkboard'];

      if (dataStr != null && dataStr.isNotEmpty) {
        final List<dynamic> decodedBoards = jsonDecode(dataStr);
        setState(() {
          _boards = decodedBoards.map((b) {
            final title = b['title'] as String;
            final List<dynamic> notesJson = b['notes'];
            List<StickyNoteData> notes = notesJson.map((n) {
              List<DrawingPoint?> points = [];
              for (var p in n['points']) {
                if (p['isEnd'] == true) {
                  points.add(null);
                } else {
                  points.add(DrawingPoint(
                    point: Offset(p['x'], p['y']),
                    paint: Paint()
                      ..color = Color(p['color'])
                      ..strokeWidth = p['width']
                      ..strokeCap = StrokeCap.round,
                  ));
                }
              }
              return StickyNoteData(
                id: n['id'],
                position: Offset(n['dx'], n['dy']),
                paperColor: Color(n['paperColor']),
                pinColor: Color(n['pinColor']),
                rotation: n['rotation'],
                scale: n['scale'] ?? 1.0,
                width: n['width'] ?? defaultNoteSize,
                height: n['height'] ?? defaultNoteSize,
                text: n['text'],
                textFontSize: n['textFontSize'],
                textFontWeight: n['isLocked'] == true ? FontWeight.bold : null,
                assetPath: n['assetPath'],
                isProtected: n['isProtected'] ?? false,
                isLocked: n['isLocked'] ?? true,
                points: points,
              );
            }).toList();
            return CorkboardProject(title: title, notes: notes);
          }).toList();

          int ataturkIndex = _boards.indexWhere((b) => b.title == 'Atatürk Köşesi');
          if (ataturkIndex != -1) {
            _boards[ataturkIndex] = _ataturkKosesi;
          } else {
            _boards.insert(0, _ataturkKosesi);
          }

          if (_currentBoardIndex >= _boards.length) {
            _currentBoardIndex = 0;
          }
        });
        await _saveData();
      } else {
        setState(() {
          _boards = [_ataturkKosesi];
          _currentBoardIndex = 0;
        });
      }
    } catch (e) {
      setState(() {
        _boards = [_ataturkKosesi];
        _currentBoardIndex = 0;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zoomOutToFitWorld();
    });
  }

  void _zoomOutToFitWorld() {
    final MediaQueryData mediaQuery = MediaQueryData.fromView(View.of(context));
    final Size screenSize = mediaQuery.size;

    double scaleX = screenSize.width / worldWidth;
    double scaleY = screenSize.height / worldHeight;
    double bestScale = scaleX < scaleY ? scaleX : scaleY;
    bestScale *= 0.85; 

    final double dx = (screenSize.width - (worldWidth * bestScale)) / 2;
    final double dy = (screenSize.height - (worldHeight * bestScale)) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(bestScale);
  }

  void _addNoteAtCurrentView() {
    if (_selectedPinColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce bir raptiye seçmelisin!')));
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final Matrix4 inverseMatrix = Matrix4.copy(_transformationController.value)..invert();
    final Offset boardCenter = MatrixUtils.transformPoint(inverseMatrix, screenCenter);

    final double noteW = defaultNoteSize * _defaultNoteScale;
    final double noteH = defaultNoteSize * _defaultNoteScale;

    final double rawX = boardCenter.dx - (noteW / 2);
    final double rawY = boardCenter.dy - (noteH / 2);

    final newPos = Offset(
      rawX.clamp(-overflowAllowance, worldWidth - noteW + overflowAllowance),
      rawY.clamp(-overflowAllowance, worldHeight - noteH + overflowAllowance),
    );

    setState(() {
      _currentNotes.add(StickyNoteData(
        id: DateTime.now().toString(),
        position: newPos,
        paperColor: _customPaperColor,
        pinColor: _selectedPinColor!,
        rotation: (Random().nextDouble() - 0.5) * 0.08, 
        scale: _defaultNoteScale,
        width: defaultNoteSize,
        height: defaultNoteSize,
        points: [],
        isLocked: false,
      ));
      _saveData();
    });
  }

  void _showNewBoardDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.brown.shade800,
          title: const Text('Yeni Pano Oluştur', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Pano adı (Örn: TYT Matematik)',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _boards.add(CorkboardProject(title: controller.text.trim(), notes: []));
                    _currentBoardIndex = _boards.length - 1;
                    _saveData();
                  });
                  _zoomOutToFitWorld();
                }
                Navigator.pop(context);
              },
              child: const Text('Oluştur', style: TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteBoard(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.brown.shade900,
          title: const Text('Panoyu Sil', style: TextStyle(color: Colors.white)),
          content: Text(
            "'${_boards[index].title}' panosunu silmek istediğinize emin misiniz?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _boards.removeAt(index);
                  if (_currentBoardIndex >= _boards.length) {
                    _currentBoardIndex = _boards.length - 1;
                  }
                  _saveData();
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.brown.shade900,
              title: const Text('Ayarlar', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kalem Kalınlığı', style: TextStyle(color: Colors.white70)),
                        Text('${_penStrokeWidth.toStringAsFixed(1)} px', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _penStrokeWidth,
                      min: 1.0,
                      max: 15.0,
                      divisions: 14,
                      activeColor: Colors.amber,
                      onChanged: (val) {
                        setDialogState(() => _penStrokeWidth = val);
                        setState(() => _penStrokeWidth = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Silgi Boyutu', style: TextStyle(color: Colors.white70)),
                        Text('${_eraserSize.toStringAsFixed(1)} px', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _eraserSize.clamp(5.0, 50.0),
                      min: 5.0,
                      max: 50.0,
                      divisions: 9,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) {
                        setDialogState(() => _eraserSize = val);
                        setState(() => _eraserSize = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kalem Opaklığı', style: TextStyle(color: Colors.white70)),
                        Text('${(_penOpacity * 100).toInt()}%', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _penOpacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setDialogState(() {
                          _penOpacity = val;
                          _updateCustomColor();
                        });
                        setState(() {});
                      },
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Yeni Kağıt Boyutu (Max 3.0x)', style: TextStyle(color: Colors.white70)),
                        Text('${_defaultNoteScale.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _defaultNoteScale.clamp(0.6, 3.0),
                      min: 0.6,
                      max: 3.0,
                      divisions: 12,
                      activeColor: Colors.greenAccent,
                      onChanged: (val) {
                        setDialogState(() => _defaultNoteScale = val);
                        setState(() => _defaultNoteScale = val);
                      },
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    const Text('Özel Kağıt Rengi Seçici', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.yellow, Colors.green, Colors.cyan, 
                            Colors.blue, Colors.purple, Colors.pink, Colors.yellow
                          ],
                        ),
                      ),
                      child: Slider(
                        value: _paperHue.clamp(0.0, 360.0),
                        min: 0.0,
                        max: 360.0,
                        activeColor: Colors.transparent,
                        inactiveColor: Colors.transparent,
                        thumbColor: Colors.white,
                        onChanged: (val) {
                          setDialogState(() {
                            _paperHue = val;
                            _customPaperColor = HSVColor.fromAHSV(1.0, _paperHue, 0.35, 0.96).toColor();
                          });
                          setState(() {
                            _customPaperColor = _customPaperColor;
                          });
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    const Text('Özel Kalem Rengi', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red],
                        ),
                      ),
                      child: Slider(
                        value: _penHue.clamp(0.0, 360.0),
                        min: 0.0,
                        max: 360.0,
                        activeColor: Colors.transparent,
                        inactiveColor: Colors.transparent,
                        thumbColor: Colors.white,
                        onChanged: (val) {
                          setDialogState(() {
                            _penHue = val;
                            _updateCustomColor();
                          });
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat', style: TextStyle(color: Colors.amber))),
              ],
            );
          },
        );
      },
    );
  }

  void _updateCustomColor() {
    _selectedTool = 'pen';
    _selectedPenColor = HSVColor.fromAHSV(1.0, _penHue, 1.0, 1.0).toColor().withValues(alpha: _penOpacity);
  }

  void _selectPresetPenColor(Color color) {
    setState(() {
      _selectedTool = 'pen';
      _selectedPenColor = color.withValues(alpha: _penOpacity);
    });
  }

  Widget _buildPin(Color pinColor) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: pinColor,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 3, offset: const Offset(1, 2))],
      ),
    );
  }

  Widget _buildCutoutTitle(String title) {
    return Positioned(
      top: frameBorder + 20,
      left: 0,
      right: 0,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 20,
          children: List.generate(title.length, (index) {
            String char = title[index];
            if (char == ' ') return const SizedBox(width: 90);
            
            final rand = Random(char.codeUnitAt(0) + index);
            double rot = (rand.nextDouble() - 0.5) * 0.15; 
            
            return Transform.rotate(
              angle: rot,
              child: Container(
                width: 280,
                height: 380, 
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(6, 8))],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        char.toUpperCase(),
                        style: const TextStyle(fontSize: 240, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      left: 127,
                      child: _buildPin(_pinColors[rand.nextInt(_pinColors.length)]),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNoteWidget(StickyNoteData note) {
    double noteW = note.width * note.scale;
    double noteH = note.height * note.scale;

    return Positioned(
      left: note.position.dx,
      top: note.position.dy,
      // PERFORMANS: RepaintBoundary ile kaydırırken kasma önlenir
      child: RepaintBoundary(
        child: GestureDetector(
          onDoubleTap: () {
            setState(() {
              note.isLocked = !note.isLocked;
              _saveData();
            });
          },
          onTap: (_selectedTool == 'scissors' && !note.isProtected && !note.isLocked)
              ? () {
                  setState(() {
                    _currentNotes.remove(note);
                    _saveData();
                  });
                }
              : null,
          onPanUpdate: (_selectedTool == 'hand' && !note.isLocked)
              ? (details) {
                  setState(() {
                    Offset movingPos = note.position + details.delta;
                    
                    double pinX = movingPos.dx + (noteW / 2);
                    double pinY = movingPos.dy - 5;

                    pinX = pinX.clamp(frameBorder, worldWidth - frameBorder);
                    pinY = pinY.clamp(frameBorder, worldHeight - frameBorder);

                    note.position = Offset(
                      pinX - (noteW / 2),
                      pinY + 5,
                    );
                    _saveData();
                  });
                }
              : null,
          child: Transform.rotate(
            angle: note.rotation,
            child: Container(
              width: noteW,
              height: noteH,
              decoration: BoxDecoration(
                color: note.paperColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(3, 3)),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (note.assetPath != null)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            note.assetPath!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.image_not_supported, size: 36, color: Colors.brown),
                                  SizedBox(height: 5),
                                  Text('Fotoğraf Bulunamadı', style: TextStyle(fontFamily: 'cursive', fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center,)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (note.text != null)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 25, left: 15, right: 15, bottom: 15),
                        child: SingleChildScrollView(
                          child: Text(
                            note.text!,
                            style: TextStyle(
                              fontSize: (note.textFontSize ?? 18) + 2.0,
                              fontWeight: note.textFontWeight ?? FontWeight.w700,
                              fontFamily: 'cursive',
                              color: Colors.black87,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  
                  if (!note.isProtected && note.assetPath == null)
                    Positioned.fill(
                      child: ClipRect(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) {
                            if (_selectedTool == 'hand' || _selectedTool == 'scissors' || note.isLocked) return;
                            
                            note.activePointers.add(event.pointer);
                            // 2 parmak veya daha fazla parmak varsa çizimi engelle (zoom/pan yapılsın)
                            if (note.activePointers.length > 1) return;

                            final localPos = event.localPosition;
                            Paint currentPaint = Paint()
                              ..color = _selectedTool == 'eraser' ? note.paperColor : _selectedPenColor
                              ..strokeWidth = _selectedTool == 'eraser' ? _eraserSize : _penStrokeWidth
                              ..strokeCap = StrokeCap.round;

                            note.points.add(DrawingPoint(point: localPos, paint: currentPaint));
                            note.pointsNotifier.value = List.from(note.points);
                          },
                          onPointerMove: (event) {
                            if (_selectedTool == 'hand' || _selectedTool == 'scissors' || note.isLocked) return;
                            if (note.activePointers.length > 1) return; // Çoklu parmakta çizimi durdur
                            if (note.points.isEmpty) return;

                            final localPos = event.localPosition;
                            Paint currentPaint = Paint()
                              ..color = _selectedTool == 'eraser' ? note.paperColor : _selectedPenColor
                              ..strokeWidth = _selectedTool == 'eraser' ? _eraserSize : _penStrokeWidth
                              ..strokeCap = StrokeCap.round;

                            note.points.add(DrawingPoint(point: localPos, paint: currentPaint));
                            note.pointsNotifier.value = List.from(note.points);
                          },
                          onPointerUp: (event) {
                            note.activePointers.remove(event.pointer);
                            if (_selectedTool == 'hand' || _selectedTool == 'scissors' || note.isLocked) return;
                            if (note.points.isNotEmpty) {
                              note.points.add(null);
                              note.pointsNotifier.value = List.from(note.points);
                              _saveData();
                            }
                          },
                          onPointerCancel: (event) {
                            note.activePointers.remove(event.pointer);
                          },
                          child: ValueListenableBuilder<List<DrawingPoint?>>(
                            valueListenable: note.pointsNotifier,
                            builder: (context, currentPoints, child) {
                              return CustomPaint(
                                painter: NotePainter(points: currentPoints),
                                size: Size.infinite,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  
                  Positioned(
                    top: -5,
                    left: (noteW / 2) - 7,
                    child: _buildPin(note.pinColor),
                  ),

                  if (note.isLocked)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock, size: 14, color: Colors.amber),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        toolbarHeight: 65,
        backgroundColor: Colors.brown.shade900,
        elevation: 5,
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _boards.length,
                  itemBuilder: (context, index) {
                    bool isActive = _currentBoardIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentBoardIndex = index);
                        _zoomOutToFitWorld();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6, top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.brown.shade600 : Colors.brown.shade800,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border.all(color: isActive ? Colors.white54 : Colors.transparent),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _boards[index].title,
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.white60,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                            if (_boards.length > 1 && index != 0) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _confirmDeleteBoard(index),
                                child: Icon(Icons.close, size: 18, color: isActive ? Colors.white : Colors.white54),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 10),
              child: IconButton(
                icon: const Icon(Icons.add_box, color: Colors.amber, size: 32),
                onPressed: _showNewBoardDialog,
                tooltip: 'Yeni Pano Ekle',
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: InteractiveViewer(
                constrained: false, 
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(2000), 
                minScale: 0.05,
                maxScale: 3.0,
                panEnabled: _selectedTool == 'hand',
                scaleEnabled: true,
                child: SizedBox(
                  width: worldWidth,
                  height: worldHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.brown.shade500,
                            border: Border.all(color: Colors.brown.shade900, width: frameBorder),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 30, spreadRadius: 10)
                            ],
                          ),
                        ),
                      ),
                      
                      _buildCutoutTitle(_boards[_currentBoardIndex].title),

                      for (var note in _currentNotes.where((n) => !n.isProtected))
                        _buildNoteWidget(note),

                      for (var note in _currentNotes.where((n) => n.isProtected))
                        _buildNoteWidget(note),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              color: Colors.brown.shade900,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildModeButton(Icons.back_hand, 'Taşı', 'hand'),
                          _buildModeButton(Icons.content_cut, 'Makas', 'scissors'),
                          const VerticalDivider(color: Colors.white30, thickness: 1, indent: 5, endIndent: 5),
                          const Text('Raptiye:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 4),
                          for (var pinColor in _pinColors)
                            GestureDetector(
                              onTap: () => setState(() => _selectedPinColor = pinColor),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: pinColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _selectedPinColor == pinColor ? Colors.white : Colors.transparent, width: 2),
                                ),
                              ),
                            ),
                          const VerticalDivider(color: Colors.white30, thickness: 1, indent: 5, endIndent: 5),
                          const Text('Kağıt Ekle:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _addNoteAtCurrentView,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _customPaperColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber, width: 2),
                              ),
                              child: const Icon(Icons.add, size: 18, color: Colors.black54),
                            ),
                          ),
                          const VerticalDivider(color: Colors.white30, thickness: 1, indent: 5, endIndent: 5),
                          const Text('Kalemler:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 4),
                          _buildColorToolButton(Colors.black, 'Siyah'),
                          _buildColorToolButton(Colors.red, 'Kırmızı'),
                          _buildColorToolButton(Colors.blue, 'Mavi'),
                          _buildModeButton(Icons.cleaning_services, 'Silgi', 'eraser'),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.amber, size: 28),
                            onPressed: _showSettingsDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Kaydır', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(IconData icon, String label, String toolType) {
    bool isSelected = _selectedTool == toolType;
    return GestureDetector(
      onTap: () => setState(() => _selectedTool = toolType),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: isSelected ? Colors.white24 : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildColorToolButton(Color baseColor, String label) {
    Color actualColor = baseColor.withValues(alpha: _penOpacity);
    bool isSelected = _selectedTool == 'pen' && _selectedPenColor == actualColor;
    return GestureDetector(
      onTap: () => _selectPresetPenColor(baseColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: isSelected ? Colors.white24 : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(color: actualColor, shape: BoxShape.circle)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class NotePainter extends CustomPainter {
  final List<DrawingPoint?> points;
  NotePainter({required this.points});

  @override
  void paint(Canvas sizeCanvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        sizeCanvas.drawLine(points[i]!.point, points[i + 1]!.point, points[i]!.paint);
      } else if (points[i] != null && points[i + 1] == null) {
        sizeCanvas.drawPoints(ui.PointMode.points, [points[i]!.point], points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NotePainter oldDelegate) => true;
}