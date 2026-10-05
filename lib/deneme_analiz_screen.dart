import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. ANA SEÇİM EKRANI (HUB)
// ==========================================
class DenemeAnalizScreen extends StatelessWidget {
  const DenemeAnalizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Deneme & Analiz Merkezi'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHubCard(
                context,
                title: 'Deneme Analizi (A4 Şablonu)',
                subtitle: 'Soru analizi, doğru/yanlış grafiği ve yanlış/boşlarım defteri',
                icon: Icons.description_rounded,
                color: Colors.pinkAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DenemeAnalizListScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildHubCard(
                context,
                title: 'Net Takip & Gelişim Grafikleri',
                subtitle: 'Şablon verilerine göre alan, ders ve özel tarih filtreli grafikler',
                icon: Icons.analytics_rounded,
                color: Colors.cyanAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NetTrackerScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 15, spreadRadius: 2)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                        child: Icon(icon, color: color, size: 36),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. NET TAKİP & GRAFİK EKRANI (A4 Verilerinden Beslenir)
// ==========================================
class NetTrackerScreen extends StatefulWidget {
  const NetTrackerScreen({super.key});

  @override
  State<NetTrackerScreen> createState() => _NetTrackerScreenState();
}

class _NetTrackerScreenState extends State<NetTrackerScreen> {
  List<AnalizSheetRecord> sheets = [];

  // Filtreler
  String selectedAreaFilter = 'Tüm Alanlar'; 
  String chartTimeRange = 'Tüm Zamanlar'; 
  DateTime? customStartDate;
  DateTime? customEndDate;
  String chartSelectedLesson = 'Genel (Toplam Net)';
  String chartType = 'Sütun'; 

  @override
  void initState() {
    super.initState();
    _loadSheets();
  }

  Future<void> _loadSheets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['a4_analiz_sheets'] != null) {
        final String raw = doc.data()!['a4_analiz_sheets'];
        final List decoded = jsonDecode(raw);
        setState(() {
          sheets = decoded.map((e) => AnalizSheetRecord.fromJson(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: customStartDate != null && customEndDate != null
          ? DateTimeRange(start: customStartDate!, end: customEndDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent, surface: Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customStartDate = picked.start;
        customEndDate = picked.end;
      });
    }
  }

  List<String> _getAvailableLessonsForFilter() {
    Set<String> lessons = {'Genel (Toplam Net)'};
    for (var sheet in sheets) {
      if (selectedAreaFilter == 'Tüm Alanlar' || sheet.mode.contains(selectedAreaFilter)) {
        for (var l in sheet.lessons) {
          lessons.add(l.lessonName);
        }
      }
    }
    return lessons.toList();
  }

  List<Map<String, dynamic>> _getFilteredChartData() {
    DateTime now = DateTime.now();

    List<AnalizSheetRecord> filtered = sheets.where((sheet) {
      if (selectedAreaFilter != 'Tüm Alanlar' && !sheet.mode.contains(selectedAreaFilter)) {
        return false;
      }

      DateTime? dt = sheet.parsedDate;
      if (dt == null) return true;

      if (chartTimeRange == 'Son 1 Ay') {
        return dt.isAfter(now.subtract(const Duration(days: 30)));
      } else if (chartTimeRange == 'Son 3 Ay') {
        return dt.isAfter(now.subtract(const Duration(days: 90)));
      } else if (chartTimeRange == 'Son 6 Ay') {
        return dt.isAfter(now.subtract(const Duration(days: 180)));
      } else if (chartTimeRange == 'Özel Aralık' && customStartDate != null && customEndDate != null) {
        return dt.isAfter(customStartDate!.subtract(const Duration(days: 1))) &&
               dt.isBefore(customEndDate!.add(const Duration(days: 1)));
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      DateTime? dtA = a.parsedDate;
      DateTime? dtB = b.parsedDate;
      if (dtA == null || dtB == null) return 0;
      return dtA.compareTo(dtB);
    });

    List<Map<String, dynamic>> dataPoints = [];
    for (var sheet in filtered) {
      double d = 0, y = 0, n = 0;

      if (chartSelectedLesson == 'Genel (Toplam Net)') {
        n = sheet.totalNet;
        d = sheet.totalDogru.toDouble();
        y = sheet.totalYanlis.toDouble();
      } else {
        bool found = false;
        for (var l in sheet.lessons) {
          if (l.lessonName == chartSelectedLesson) {
            d = l.dogru.toDouble();
            y = l.yanlis.toDouble();
            n = l.net;
            found = true;
            break;
          }
        }
        if (!found) continue;
      }

      dataPoints.add({
        'examName': sheet.examName,
        'date': sheet.date,
        'dogru': d,
        'yanlis': y,
        'net': n,
      });
    }

    return dataPoints;
  }

  @override
  Widget build(BuildContext context) {
    List<String> availableLessons = _getAvailableLessonsForFilter();
    if (!availableLessons.contains(chartSelectedLesson)) {
      chartSelectedLesson = 'Genel (Toplam Net)';
    }
    List<Map<String, dynamic>> chartData = _getFilteredChartData();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Net Takip & Gelişim Grafikleri'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gelişim Grafiği 📈', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ToggleButtons(
                        borderColor: Colors.white24,
                        selectedBorderColor: Colors.cyanAccent,
                        fillColor: Colors.cyanAccent.withValues(alpha: 0.2),
                        color: Colors.white60,
                        selectedColor: Colors.cyanAccent,
                        borderRadius: BorderRadius.circular(8),
                        constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
                        isSelected: [chartType == 'Sütun', chartType == 'Çizgi'],
                        onPressed: (index) {
                          setState(() {
                            chartType = index == 0 ? 'Sütun' : 'Çizgi';
                          });
                        },
                        children: const [
                          Text('Sütun', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('Çizgi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF2C2C2C),
                    initialValue: selectedAreaFilter,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Alan / Kategori Filtresi',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: ['Tüm Alanlar', 'TYT', 'AYT Sayısal', 'AYT Eşit Ağırlık', 'AYT Sözel']
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedAreaFilter = val!),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF2C2C2C),
                          initialValue: chartTimeRange,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Zaman Aralığı',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF2C2C2C),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          items: ['Tüm Zamanlar', 'Son 1 Ay', 'Son 3 Ay', 'Son 6 Ay', 'Özel Aralık']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              chartTimeRange = val!;
                              if (chartTimeRange == 'Özel Aralık' && customStartDate == null) {
                                _selectCustomDateRange(context);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF2C2C2C),
                          initialValue: chartSelectedLesson,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Ders / Kategori',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF2C2C2C),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          items: availableLessons
                              .map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) => setState(() => chartSelectedLesson = val!),
                        ),
                      ),
                    ],
                  ),

                  if (chartTimeRange == 'Özel Aralık') ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            customStartDate != null && customEndDate != null
                                ? 'Seçilen Aralık: ${customStartDate!.day}.${customStartDate!.month}.${customStartDate!.year} - ${customEndDate!.day}.${customEndDate!.month}.${customEndDate!.year}'
                                : 'Tarih aralığı seçilmedi.',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _selectCustomDateRange(context),
                          icon: const Icon(Icons.date_range, size: 14, color: Colors.cyanAccent),
                          label: const Text('Tarih Seç', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  
                  chartData.isEmpty
                      ? const SizedBox(
                          height: 220,
                          child: Center(
                            child: Text('Şablon verilerine göre eşleşen deneme kaydı bulunamadı.\n(Deneme analizlerinden veri eklediğinizde burada görünür)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ),
                        )
                      : SizedBox(
                          height: 240,
                          child: CustomPaint(
                            size: const Size(double.infinity, 240),
                            painter: ChartPainter(data: chartData, chartType: chartType),
                          ),
                        ),
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendDot(Colors.greenAccent, 'Doğru'),
                      const SizedBox(width: 16),
                      _buildLegendDot(Colors.redAccent, 'Yanlış'),
                      const SizedBox(width: 16),
                      _buildLegendDot(Colors.cyanAccent, 'Net'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ==========================================
// 3. ÖZEL GRAFİK ÇİZCİ (CUSTOM PAINTER)
// ==========================================
class ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String chartType;

  ChartPainter({required this.data, required this.chartType});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final Paint gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;

    final Paint netLinePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Paint dogruLinePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint yanlisLinePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double paddingLeft = 35;
    double paddingBottom = 30;
    double paddingTop = 20;
    double chartWidth = size.width - paddingLeft - 10;
    double chartHeight = size.height - paddingBottom - paddingTop;

    double maxY = 40;
    for (var item in data) {
      double n = (item['net'] as num).toDouble();
      double d = (item['dogru'] as num).toDouble();
      maxY = math.max(maxY, math.max(n, d));
    }
    maxY = (maxY <= 0) ? 40 : (maxY * 1.15);

    for (int i = 0; i <= 4; i++) {
      double y = paddingTop + (chartHeight / 4) * i;
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - 10, y), gridPaint);

      double val = maxY - (maxY / 4) * i;
      TextPainter tp = TextPainter(
        text: TextSpan(text: val.toStringAsFixed(0), style: const TextStyle(color: Colors.white38, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }

    int count = data.length;
    double stepX = chartWidth / math.max(1, count);

    if (chartType == 'Sütun') {
      double barWidth = math.min(18, stepX * 0.25);

      for (int i = 0; i < count; i++) {
        double x = paddingLeft + stepX * i + (stepX / 2);
        double d = (data[i]['dogru'] as num).toDouble();
        double y = (data[i]['yanlis'] as num).toDouble();
        double n = (data[i]['net'] as num).toDouble();

        double hD = (d / maxY) * chartHeight;
        double hY = (y / maxY) * chartHeight;
        double hN = (n / maxY) * chartHeight;

        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - barWidth * 1.5, paddingTop + chartHeight - hD, barWidth, hD), const Radius.circular(3)),
          Paint()..color = Colors.greenAccent.withValues(alpha: 0.8),
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - barWidth / 2, paddingTop + chartHeight - hY, barWidth, hY), const Radius.circular(3)),
          Paint()..color = Colors.redAccent.withValues(alpha: 0.8),
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x + barWidth * 0.5, paddingTop + chartHeight - hN, barWidth, hN), const Radius.circular(3)),
          Paint()..color = Colors.cyanAccent.withValues(alpha: 0.9),
        );

        String label = data[i]['examName'];
        if (label.length > 8) label = '${label.substring(0, 6)}..';
        TextPainter tpX = TextPainter(
          text: TextSpan(text: label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          textDirection: TextDirection.ltr,
        );
        tpX.layout();
        canvas.save();
        canvas.translate(x, paddingTop + chartHeight + 8);
        canvas.rotate(-0.3);
        tpX.paint(canvas, Offset(-tpX.width / 2, 0));
        canvas.restore();
      }
    } else {
      Path pathNet = Path();
      Path pathDogru = Path();
      Path pathYanlis = Path();

      List<Offset> pointsNet = [];
      List<Offset> pointsDogru = [];
      List<Offset> pointsYanlis = [];

      for (int i = 0; i < count; i++) {
        double x = paddingLeft + stepX * i + (stepX / 2);
        double d = (data[i]['dogru'] as num).toDouble();
        double y = (data[i]['yanlis'] as num).toDouble();
        double n = (data[i]['net'] as num).toDouble();

        double yPosD = paddingTop + chartHeight - (d / maxY) * chartHeight;
        double yPosY = paddingTop + chartHeight - (y / maxY) * chartHeight;
        double yPosN = paddingTop + chartHeight - (n / maxY) * chartHeight;

        pointsDogru.add(Offset(x, yPosD));
        pointsYanlis.add(Offset(x, yPosY));
        pointsNet.add(Offset(x, yPosN));

        if (i == 0) {
          pathDogru.moveTo(x, yPosD);
          pathYanlis.moveTo(x, yPosY);
          pathNet.moveTo(x, yPosN);
        } else {
          pathDogru.lineTo(x, yPosD);
          pathYanlis.lineTo(x, yPosY);
          pathNet.lineTo(x, yPosN);
        }

        String label = data[i]['examName'];
        if (label.length > 8) label = '${label.substring(0, 6)}..';
        TextPainter tpX = TextPainter(
          text: TextSpan(text: label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          textDirection: TextDirection.ltr,
        );
        tpX.layout();
        canvas.save();
        canvas.translate(x, paddingTop + chartHeight + 8);
        canvas.rotate(-0.3);
        tpX.paint(canvas, Offset(-tpX.width / 2, 0));
        canvas.restore();
      }

      canvas.drawPath(pathDogru, dogruLinePaint);
      canvas.drawPath(pathYanlis, yanlisLinePaint);
      canvas.drawPath(pathNet, netLinePaint);

      for (var pt in pointsDogru) {
        canvas.drawCircle(pt, 3.5, Paint()..color = Colors.greenAccent);
      }
      for (var pt in pointsYanlis) {
        canvas.drawCircle(pt, 3.5, Paint()..color = Colors.redAccent);
      }
      for (var pt in pointsNet) {
        canvas.drawCircle(pt, 4.5, Paint()..color = Colors.cyanAccent);
        canvas.drawCircle(pt, 2, Paint()..color = Colors.black);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 4. A4 DENEME ANALİZLERİ (MODELLER VE LİSTE)
// ==========================================
class LessonDetail {
  String lessonName;
  int totalQuestions;
  int dogru;
  int yanlis;
  int bos;
  int sureMinutes;
  List<String> yanlisBoslar;

  LessonDetail({
    required this.lessonName,
    required this.totalQuestions,
    this.dogru = 0,
    this.yanlis = 0,
    this.bos = 0,
    this.sureMinutes = 0,
    List<String>? yanlisBoslar,
  }) : yanlisBoslar = yanlisBoslar ?? [];

  double get net => double.parse((dogru - (yanlis * 0.25)).toStringAsFixed(2));

  Map<String, dynamic> toJson() => {
        'lessonName': lessonName,
        'totalQuestions': totalQuestions,
        'dogru': dogru,
        'yanlis': yanlis,
        'bos': bos,
        'sureMinutes': sureMinutes,
        'yanlisBoslar': yanlisBoslar,
      };

  factory LessonDetail.fromJson(Map<String, dynamic> json) => LessonDetail(
        lessonName: json['lessonName'] ?? '',
        totalQuestions: json['totalQuestions'] ?? 40,
        dogru: json['dogru'] ?? 0,
        yanlis: json['yanlis'] ?? 0,
        bos: json['bos'] ?? 0,
        sureMinutes: json['sureMinutes'] ?? 0,
        yanlisBoslar: List<String>.from(json['yanlisBoslar'] ?? []),
      );
}

class AnalizSheetRecord {
  final String id;
  final String examName;
  final String mode;
  String date;
  List<LessonDetail> lessons;
  String genelNot;

  AnalizSheetRecord({
    required this.id,
    required this.examName,
    required this.mode,
    required this.date,
    required this.lessons,
    this.genelNot = '',
  });

  double get totalNet {
    double sum = 0;
    for (var l in lessons) {
      sum += l.net;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  int get totalSure => lessons.fold(0, (sum, l) => sum + l.sureMinutes);
  int get totalDogru => lessons.fold(0, (sum, l) => sum + l.dogru);
  int get totalYanlis => lessons.fold(0, (sum, l) => sum + l.yanlis);

  DateTime? get parsedDate {
    try {
      List<String> parts = date.split('.');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'examName': examName,
        'mode': mode,
        'date': date,
        'lessons': lessons.map((e) => e.toJson()).toList(),
        'genelNot': genelNot,
      };

  factory AnalizSheetRecord.fromJson(Map<String, dynamic> json) => AnalizSheetRecord(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        examName: json['examName'] ?? '',
        mode: json['mode'] ?? 'Branş Deneme',
        date: json['date'] ?? '',
        lessons: (json['lessons'] as List? ?? []).map((e) => LessonDetail.fromJson(e)).toList(),
        genelNot: json['genelNot'] ?? '',
      );
}

class DenemeAnalizListScreen extends StatefulWidget {
  const DenemeAnalizListScreen({super.key});

  @override
  State<DenemeAnalizListScreen> createState() => _DenemeAnalizListScreenState();
}

class _DenemeAnalizListScreenState extends State<DenemeAnalizListScreen> {
  List<AnalizSheetRecord> sheets = [];

  @override
  void initState() {
    super.initState();
    _loadSheets();
  }

  Future<void> _loadSheets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['a4_analiz_sheets'] != null) {
        final String raw = doc.data()!['a4_analiz_sheets'];
        final List decoded = jsonDecode(raw);
        setState(() {
          sheets = decoded.map((e) => AnalizSheetRecord.fromJson(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSheets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String encoded = jsonEncode(sheets.map((e) => e.toJson()).toList());
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'a4_analiz_sheets': encoded}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showAddTemplateDialog() {
    final TextEditingController examNameController = TextEditingController();
    String examTypeMode = 'Branş Deneme';
    String selectedArea = 'TYT';
    String selectedLesson = 'Türkçe';

    final Map<String, int> questionCounts = {
      'Türkçe': 40,
      'Sosyal Bilgiler': 20,
      'Temel Matematik': 40,
      'Fen Bilimleri': 20,
      'Matematik (AYT)': 40,
      'Türk Dili ve Edebiyatı': 24,
      'Tarih-1': 10,
      'Coğrafya-1': 6,
      'Tarih-2': 11,
      'Coğrafya-2': 11,
      'Felsefe Grubu': 12,
      'Din Kültürü ve Ahlak Bilgisi': 6,
      'Fizik': 14,
      'Kimya': 13,
      'Biyoloji': 13,
    };

    final Map<String, List<String>> areaLessons = {
      'TYT': ['Türkçe', 'Sosyal Bilgiler', 'Temel Matematik', 'Fen Bilimleri'],
      'AYT Sayısal': ['Matematik (AYT)', 'Fizik', 'Kimya', 'Biyoloji'],
      'AYT Eşit Ağırlık': ['Matematik (AYT)', 'Türk Dili ve Edebiyatı', 'Tarih-1', 'Coğrafya-1'],
      'AYT Sözel': ['Türk Dili ve Edebiyatı', 'Tarih-1', 'Coğrafya-1', 'Tarih-2', 'Coğrafya-2', 'Felsefe Grubu', 'Din Kültürü ve Ahlak Bilgisi'],
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Yeni Analiz Şablonu Oluştur', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: examNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Deneme Adı (Örn: Özdebir TYT 1)', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 16),
                const Text('Alan / Sınav Grubu:', style: TextStyle(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF2C2C2C),
                  initialValue: selectedArea,
                  style: const TextStyle(color: Colors.white),
                  items: ['TYT', 'AYT Sayısal', 'AYT Eşit Ağırlık', 'AYT Sözel'].map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedArea = val!;
                      selectedLesson = areaLessons[selectedArea]!.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Deneme Türü:', style: TextStyle(color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Branş', style: TextStyle(color: Colors.white, fontSize: 13)),
                        value: 'Branş Deneme',
                        groupValue: examTypeMode,
                        activeColor: Colors.pinkAccent,
                        onChanged: (val) => setDialogState(() => examTypeMode = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Genel', style: TextStyle(color: Colors.white, fontSize: 13)),
                        value: 'Genel Deneme',
                        groupValue: examTypeMode,
                        activeColor: Colors.pinkAccent,
                        onChanged: (val) => setDialogState(() => examTypeMode = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (examTypeMode == 'Branş Deneme') ...[
                  const Text('Ders Seçimi:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF2C2C2C),
                    initialValue: selectedLesson,
                    style: const TextStyle(color: Colors.white),
                    items: areaLessons[selectedArea]!.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setDialogState(() => selectedLesson = val!),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              onPressed: () {
                if (examNameController.text.trim().isEmpty) return;
                final now = DateTime.now();
                String dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

                setState(() {
                  if (examTypeMode == 'Branş Deneme') {
                    final newRecord = AnalizSheetRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      examName: examNameController.text.trim(),
                      mode: 'Branş Deneme ($selectedArea)',
                      date: dateStr,
                      lessons: [
                        LessonDetail(
                          lessonName: selectedLesson,
                          totalQuestions: questionCounts[selectedLesson] ?? 40,
                        ),
                      ],
                    );
                    sheets.insert(0, newRecord);
                  } else {
                    List<String> groupLessons = areaLessons[selectedArea]!;
                    List<LessonDetail> allLessons = groupLessons.map((l) => LessonDetail(
                      lessonName: l,
                      totalQuestions: questionCounts[l] ?? 40,
                    )).toList();

                    final newRecord = AnalizSheetRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      examName: examNameController.text.trim(),
                      mode: 'Genel Deneme ($selectedArea)',
                      date: dateStr,
                      lessons: allLessons,
                    );
                    sheets.insert(0, newRecord);
                  }
                });
                _saveSheets();
                Navigator.pop(context);
              },
              child: const Text('Şablonu Oluştur', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('Deneme Analizleri (A4)'), backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.pinkAccent,
        onPressed: _showAddTemplateDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Analiz Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: sheets.isEmpty
          ? const Center(child: Text('Henüz analiz şablonu oluşturulmamış.\n"Analiz Ekle" butonuna basarak ilk şablonunu oluştur! 🚀', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sheets.length,
              itemBuilder: (context, index) {
                final sheet = sheets[index];
                bool isBrans = sheet.lessons.length == 1;
                String subText = isBrans ? '${sheet.lessons.first.lessonName} • ${sheet.mode}' : sheet.mode;

                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(sheet.examName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('$subText • Tarih: ${sheet.date}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text('D:${sheet.totalDogru}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text('Y:${sheet.totalYanlis}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text('N:${sheet.totalNet}', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              sheets.removeAt(index);
                            });
                            _saveSheets();
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DenemeAnalizDetailScreen(record: sheet, onUpdate: _saveSheets)),
                      );
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 5. A4 SAYFASI DETAY GÖRÜNÜMÜ
// ==========================================
class DenemeAnalizDetailScreen extends StatefulWidget {
  final AnalizSheetRecord record;
  final VoidCallback onUpdate;

  const DenemeAnalizDetailScreen({super.key, required this.record, required this.onUpdate});

  @override
  State<DenemeAnalizDetailScreen> createState() => _DenemeAnalizDetailScreenState();
}

class _DenemeAnalizDetailScreenState extends State<DenemeAnalizDetailScreen> {
  late Map<String, List<TextEditingController>> lessonControllers;
  late TextEditingController genelNotController;
  final Map<String, TextEditingController> noteControllers = {};

  @override
  void initState() {
    super.initState();
    genelNotController = TextEditingController(text: widget.record.genelNot);
    lessonControllers = {};
    for (var l in widget.record.lessons) {
      lessonControllers[l.lessonName] = [
        TextEditingController(text: l.dogru == 0 ? '' : l.dogru.toString()),
        TextEditingController(text: l.yanlis == 0 ? '' : l.yanlis.toString()),
        TextEditingController(text: l.bos == 0 ? '' : l.bos.toString()),
        TextEditingController(text: l.sureMinutes == 0 ? '' : l.sureMinutes.toString()),
      ];
      noteControllers[l.lessonName] = TextEditingController();
    }
  }

  @override
  void dispose() {
    genelNotController.dispose();
    for (var list in lessonControllers.values) {
      for (var c in list) {
        c.dispose();
      }
    }
    for (var c in noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _triggerAutoSave() {
    setState(() {
      for (var l in widget.record.lessons) {
        var controllers = lessonControllers[l.lessonName]!;
        l.dogru = int.tryParse(controllers[0].text) ?? 0;
        l.yanlis = int.tryParse(controllers[1].text) ?? 0;
        l.bos = int.tryParse(controllers[2].text) ?? 0;
        l.sureMinutes = int.tryParse(controllers[3].text) ?? 0;
      }
      widget.record.genelNot = genelNotController.text;
    });
    widget.onUpdate();
  }

  void _validateAndSave(LessonDetail lesson, int changedIndex) {
    var controllers = lessonControllers[lesson.lessonName]!;
    int d = int.tryParse(controllers[0].text) ?? 0;
    int y = int.tryParse(controllers[1].text) ?? 0;
    int b = int.tryParse(controllers[2].text) ?? 0;

    if (d + y + b > lesson.totalQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğru, yanlış ve boş toplamı soru sayısını geçemez!'), backgroundColor: Colors.redAccent),
      );
      if (changedIndex == 0) d = (lesson.totalQuestions - y - b).clamp(0, lesson.totalQuestions);
      if (changedIndex == 1) y = (lesson.totalQuestions - d - b).clamp(0, lesson.totalQuestions);
      if (changedIndex == 2) b = (lesson.totalQuestions - d - y).clamp(0, lesson.totalQuestions);

      controllers[0].text = d == 0 ? '' : d.toString();
      controllers[1].text = y == 0 ? '' : y.toString();
      controllers[2].text = b == 0 ? '' : b.toString();
    }

    _triggerAutoSave();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    try {
      List<String> parts = widget.record.date.split('.');
      if (parts.length == 3) {
        initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.pinkAccent, surface: Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        widget.record.date = '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      });
      widget.onUpdate();
    }
  }

  void _addNote(LessonDetail lesson) {
    final ctrl = noteControllers[lesson.lessonName];
    if (ctrl == null || ctrl.text.trim().isEmpty) return;
    setState(() {
      lesson.yanlisBoslar.add(ctrl.text.trim());
      ctrl.clear();
    });
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    bool isBrans = widget.record.lessons.length == 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(widget.record.examName),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(6), color: Colors.grey.shade50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Deneme Adı: ${widget.record.examName}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Tür: ${widget.record.mode}', style: const TextStyle(color: Colors.black87, fontSize: 12)),
                            if (isBrans) ...[
                              const SizedBox(height: 2),
                              Text('Ders: ${widget.record.lessons.first.lessonName}', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 13, color: Colors.pinkAccent),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text('Tarih: ${widget.record.date} (Değiştir)', style: const TextStyle(color: Colors.pinkAccent, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: Colors.pink.shade50, border: Border.all(color: Colors.pinkAccent), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                const Text('TOPLAM NET', style: TextStyle(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('${widget.record.totalNet}', style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.blueAccent), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                const Text('TOPLAM SÜRE', style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('${widget.record.totalSure} dk', style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...widget.record.lessons.map((lesson) {
                  var controllers = lessonControllers[lesson.lessonName]!;
                  int d = lesson.dogru;
                  int y = lesson.yanlis;
                  int b = lesson.bos;
                  int s = lesson.sureMinutes;
                  double net = lesson.net;
                  int maxQ = lesson.totalQuestions;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black38), borderRadius: BorderRadius.circular(6), color: Colors.grey.shade100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${lesson.lessonName} ($maxQ Soru)', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('Net: $net', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const Divider(color: Colors.black26),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _buildInputRow('Doğru:', controllers[0], Colors.green.shade700, () => _validateAndSave(lesson, 0)),
                                  _buildInputRow('Yanlış:', controllers[1], Colors.red.shade700, () => _validateAndSave(lesson, 1)),
                                  _buildInputRow('Boş:', controllers[2], Colors.orange.shade800, () => _validateAndSave(lesson, 2)),
                                  _buildInputRow('Süre (dk):', controllers[3], Colors.blue.shade700, () => _validateAndSave(lesson, 3)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  const Text('Performans', style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 80,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _buildBar('D', d, maxQ, Colors.green),
                                        _buildBar('Y', y, maxQ, Colors.red),
                                        _buildBar('B', b, maxQ, Colors.orange),
                                        _buildBar('S(dk)', s, 90, Colors.blue),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Yanlış / Boşlarım', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: TextField(
                                  controller: noteControllers[lesson.lessonName],
                                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'Analiz veya yanlış nedeni ekle...',
                                    hintStyle: const TextStyle(color: Colors.black38),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.add_circle, color: Colors.pinkAccent, size: 24), onPressed: () => _addNote(lesson)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        lesson.yanlisBoslar.isEmpty
                            ? const Text('Henüz eklenmedi.', style: TextStyle(color: Colors.black38, fontSize: 11))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: lesson.yanlisBoslar.length,
                                itemBuilder: (context, noteIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                                        Expanded(child: Text(lesson.yanlisBoslar[noteIndex], style: const TextStyle(color: Colors.black87, fontSize: 11))),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              lesson.yanlisBoslar.removeAt(noteIndex);
                                            });
                                            widget.onUpdate();
                                          },
                                          child: const Icon(Icons.close, color: Colors.red, size: 14),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  );
                }),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(6), color: Colors.grey.shade50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Genel Notlar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: genelNotController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Bu deneme ile ilgili genel değerlendirmelerin...',
                          hintStyle: TextStyle(color: Colors.black38),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) => _triggerAutoSave(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController controller, Color color, VoidCallback onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          SizedBox(width: 75, child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) => onChanged(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int value, int maxValue, Color color) {
    double factor = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    double height = (factor * 45).clamp(4.0, 45.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value', style: const TextStyle(color: Colors.black54, fontSize: 9)),
        const SizedBox(height: 2),
        Container(width: 12, height: height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}