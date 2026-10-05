import 'dart:convert';
import 'package:flutter/material.dart';
import 'user_data_service.dart';

// --- VERİ MODELLERİ ---

class PlanTask {
  String id;
  String subject;
  String topic;
  String? time;
  String? testCount;
  String? questionCount;
  String? videoCount;
  String? note;
  int status;

  PlanTask({
    required this.id,
    required this.subject,
    required this.topic,
    this.time,
    this.testCount,
    this.questionCount,
    this.videoCount,
    this.note,
    this.status = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'topic': topic,
        'time': time,
        'testCount': testCount,
        'questionCount': questionCount,
        'videoCount': videoCount,
        'note': note,
        'status': status,
      };

  factory PlanTask.fromJson(Map<String, dynamic> json) => PlanTask(
        id: json['id'] ?? UniqueKey().toString(),
        subject: json['subject'] ?? '',
        topic: json['topic'] ?? '',
        time: json['time'],
        testCount: json['testCount'],
        questionCount: json['questionCount'],
        videoCount: json['videoCount'],
        note: json['note'],
        status: json['status'] ?? 0,
      );
}

class DayPlan {
  DateTime date;
  List<PlanTask> tasks;

  DayPlan({required this.date, required this.tasks});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
        date: DateTime.parse(json['date']),
        tasks: (json['tasks'] as List? ?? []).map((t) => PlanTask.fromJson(t)).toList(),
      );
}

class SavedProgramModel {
  String id;
  String customName;
  String startDate;
  String endDate;
  String type;

  SavedProgramModel({
    required this.id,
    required this.customName,
    required this.startDate,
    required this.endDate,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customName': customName,
        'startDate': startDate,
        'endDate': endDate,
        'type': type,
      };

  factory SavedProgramModel.fromJson(Map<String, dynamic> json) => SavedProgramModel(
        id: json['id'] ?? '',
        customName: json['customName'] ?? 'Program',
        startDate: json['startDate'] ?? '',
        endDate: json['endDate'] ?? '',
        type: json['type'] ?? 'weekly',
      );
}

// --- DERS SÖZLÜĞÜ VE RENKLERİ ---
final Map<String, Map<String, dynamic>> subjectMeta = {
  'Türkçe': {'color': Colors.yellowAccent, 'type': 'Sözel', 'exam': 'TYT'},
  'Edebiyat': {'color': Colors.purpleAccent, 'type': 'Sözel', 'exam': 'AYT'},
  'Matematik': {'color': Colors.blueAccent, 'type': 'Sayısal', 'exam': 'TYT/AYT'},
  'Geometri': {'color': Colors.lightBlueAccent, 'type': 'Sayısal', 'exam': 'TYT/AYT'},
  'Fizik': {'color': Colors.cyanAccent, 'type': 'Sayısal', 'exam': 'TYT/AYT'},
  'Kimya': {'color': Colors.tealAccent, 'type': 'Sayısal', 'exam': 'TYT/AYT'},
  'Biyoloji': {'color': Colors.greenAccent, 'type': 'Sayısal', 'exam': 'TYT/AYT'},
  'Tarih': {'color': Colors.brown, 'type': 'Sözel', 'exam': 'TYT/AYT'},
  'Coğrafya': {'color': Colors.orangeAccent, 'type': 'Sözel', 'exam': 'TYT/AYT'},
  'Felsefe': {'color': Colors.pinkAccent, 'type': 'Sözel', 'exam': 'TYT'},
};

// --- GİRİŞ EKRANI ---

class HaftalikProgramScreen extends StatelessWidget {
  const HaftalikProgramScreen({super.key});

  Future<List<SavedProgramModel>> _getSavedPrograms(String type) async {
    final allData = await UserDataService.fetchAllData();
    String? jsonStr = allData['saved_programs_meta_$type'];
    if (jsonStr == null || jsonStr.isEmpty) return [];
    List decoded = jsonDecode(jsonStr);
    return decoded.map((e) => SavedProgramModel.fromJson(e)).toList();
  }

  Future<void> _saveProgramsMeta(String type, List<SavedProgramModel> list) async {
    String encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await UserDataService.saveModuleData('saved_programs_meta_$type', encoded);
  }

  void _handlePlanTap(BuildContext context, String planType, String planTitle) async {
    List<SavedProgramModel> savedPrograms = await _getSavedPrograms(planType);

    if (!context.mounted) return;

    if (savedPrograms.isEmpty) {
      _createNewProgram(context, planType, planTitle);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => SavedProgramsDialog(
          planType: planType,
          planTitle: planTitle,
          savedPrograms: savedPrograms,
          onAddNew: () {
            Navigator.pop(ctx);
            _createNewProgram(context, planType, planTitle);
          },
          onSelect: (prog) {
            Navigator.pop(ctx);
            DateTime start = DateTime.parse(prog.startDate);
            DateTime end = DateTime.parse(prog.endDate);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlanActiveScreen(
                  startDate: start,
                  endDate: end,
                  title: prog.customName,
                  programId: prog.id,
                ),
              ),
            );
          },
          onDelete: (progId) async {
            savedPrograms.removeWhere((p) => p.id == progId);
            await _saveProgramsMeta(planType, savedPrograms);
          },
        ),
      );
    }
  }

  void _createNewProgram(BuildContext context, String planType, String planTitle) async {
    if (planType == 'weekly' || planType == 'monthly') {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime(2030),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.blueAccent, surface: Color(0xFF1E1E1E))),
          child: child!,
        ),
      );

      if (picked != null && context.mounted) {
        DateTime end = planType == 'weekly' ? picked.add(const Duration(days: 6)) : picked.add(const Duration(days: 29));
        _promptProgramNameAndOpen(context, planType, planTitle, picked, end);
      }
    } else if (planType == 'custom') {
      DateTime? start = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime(2030),
        helpText: "Başlangıç Tarihi Seçin",
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.pinkAccent, surface: Color(0xFF1E1E1E))),
          child: child!,
        ),
      );

      if (start != null && context.mounted) {
        DateTime? end = await showDatePicker(
          context: context,
          initialDate: start,
          firstDate: start,
          lastDate: DateTime(2030),
          helpText: "Bitiş Tarihi Seçin",
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.pinkAccent, surface: Color(0xFF1E1E1E))),
            child: child!,
          ),
        );

        if (end != null && context.mounted) {
          _promptProgramNameAndOpen(context, planType, planTitle, start, end);
        }
      }
    }
  }

  void _promptProgramNameAndOpen(BuildContext context, String planType, String planTitle, DateTime start, DateTime end) {
    TextEditingController nameCtrl = TextEditingController(text: "$planTitle ${start.day}.${start.month}.${start.year}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Programa Özel Ad Ver", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: "Örn: 1. Program", hintStyle: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              String name = nameCtrl.text.trim();
              if (name.isEmpty) name = planTitle;
              Navigator.pop(ctx);

              String progId = UniqueKey().toString();
              SavedProgramModel newProg = SavedProgramModel(
                id: progId,
                customName: name,
                startDate: start.toIso8601String(),
                endDate: end.toIso8601String(),
                type: planType,
              );

              List<SavedProgramModel> list = await _getSavedPrograms(planType);
              list.insert(0, newProg);
              await _saveProgramsMeta(planType, list);

              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlanActiveScreen(
                      startDate: start,
                      endDate: end,
                      title: name,
                      programId: progId,
                    ),
                  ),
                );
              }
            },
            child: const Text("Oluştur", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Planlayıcı'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMainButton(context, title: 'Haftalık Plan', icon: Icons.view_week_rounded, color: Colors.blueAccent, onTap: () => _handlePlanTap(context, 'weekly', 'Haftalık Plan')),
              const SizedBox(height: 20),
              _buildMainButton(context, title: 'Aylık Plan', icon: Icons.calendar_month_rounded, color: Colors.pinkAccent, onTap: () => _handlePlanTap(context, 'monthly', 'Aylık Plan')),
              const SizedBox(height: 20),
              _buildMainButton(context, title: 'Özel Tarih Aralığı', icon: Icons.date_range_rounded, color: Colors.amberAccent, onTap: () => _handlePlanTap(context, 'custom', 'Özel Plan')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- KAYITLI PROGRAMLAR SEÇİM DİYALOĞU (Yüzde Göstergeli) ---

class SavedProgramsDialog extends StatefulWidget {
  final String planType;
  final String planTitle;
  final List<SavedProgramModel> savedPrograms;
  final VoidCallback onAddNew;
  final Function(SavedProgramModel) onSelect;
  final Function(String) onDelete;

  const SavedProgramsDialog({
    super.key,
    required this.planType,
    required this.planTitle,
    required this.savedPrograms,
    required this.onAddNew,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<SavedProgramsDialog> createState() => _SavedProgramsDialogState();
}

class _SavedProgramsDialogState extends State<SavedProgramsDialog> {
  String query = "";
  Map<String, double> progressMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllProgress();
  }

  void _loadAllProgress() async {
    final allData = await UserDataService.fetchAllData();
    Map<String, double> map = {};
    for (var prog in widget.savedPrograms) {
      String key = 'prog_data_${prog.id}';
      String? saved = allData[key];
      if (saved != null && saved.isNotEmpty) {
        List decoded = jsonDecode(saved);
        List<DayPlan> days = decoded.map((d) => DayPlan.fromJson(d)).toList();
        int total = 0;
        int completed = 0;
        for (var d in days) {
          for (var t in d.tasks) {
            total++;
            if (t.status == 1) completed++;
          }
        }
        map[prog.id] = total == 0 ? 0.0 : (completed / total);
      } else {
        map[prog.id] = 0.0;
      }
    }
    if (mounted) {
      setState(() => progressMap = map);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<SavedProgramModel> filtered = widget.savedPrograms
        .where((p) => p.customName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("${widget.planTitle}lerim", style: const TextStyle(color: Colors.white, fontSize: 18)),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 400,
        child: Column(
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Program ara...",
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 40)),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Yeni Program Oluştur", style: TextStyle(color: Colors.white)),
              onPressed: widget.onAddNew,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("Kayıtlı program bulunamadı.", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        var prog = filtered[index];
                        String dateStr = "${prog.startDate.substring(0, 10)} / ${prog.endDate.substring(0, 10)}";
                        double progVal = progressMap[prog.id] ?? 0.0;
                        int percent = (progVal * 100).toInt();

                        return Card(
                          color: const Color(0xFF2C2C2C),
                          child: ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(prog.customName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                Text("%$percent", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            subtitle: Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    title: const Text("Emin misin?", style: TextStyle(color: Colors.white)),
                                    content: Text("${prog.customName} silinecek.", style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                        onPressed: () {
                                          widget.onDelete(prog.id);
                                          Navigator.pop(ctx);
                                          setState(() {});
                                        },
                                        child: const Text("Sil"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            onTap: () => widget.onSelect(prog),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- AYLIK UZAKTAN BAKIŞ (TAKVİM) EKRANI ---
class MonthlyOverviewScreen extends StatefulWidget {
  final List<DayPlan> daysList;
  final DateTime startDate;
  final DateTime endDate;

  const MonthlyOverviewScreen({
    super.key,
    required this.daysList,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<MonthlyOverviewScreen> createState() => _MonthlyOverviewScreenState();
}

class _MonthlyOverviewScreenState extends State<MonthlyOverviewScreen> {
  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    _focusedDate = widget.startDate;
  }

  void _changeMonth(int increment) {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + increment, 1);
    });
  }

  Color _getSubjectColor(String subject) {
    return subjectMeta[subject]?['color'] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final int firstDayOfWeek = DateTime(_focusedDate.year, _focusedDate.month, 1).weekday; // 1: Pzt, 7: Pazar

    final List<String> monthNames = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];

    final List<String> weekDays = ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'];

    Map<String, List<PlanTask>> dateTaskMap = {};
    for (var day in widget.daysList) {
      String key = "${day.date.year}-${day.date.month}-${day.date.day}";
      dateTaskMap[key] = day.tasks;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('${monthNames[_focusedDate.month - 1]} ${_focusedDate.year}', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.tealAccent),
            onPressed: () => setState(() => _focusedDate = widget.startDate),
            tooltip: 'Başlangıç Ayına Git',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white70),
            onPressed: () => _changeMonth(-1),
            tooltip: 'Önceki Ay',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white70),
            onPressed: () => _changeMonth(1),
            tooltip: 'Sonraki Ay',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1F1F1F),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: weekDays.map((day) {
                return Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 0.7,
              ),
              itemCount: daysInMonth + (firstDayOfWeek - 1),
              itemBuilder: (context, index) {
                if (index < firstDayOfWeek - 1) {
                  return const SizedBox.shrink();
                }

                int dayNumber = index - (firstDayOfWeek - 2);
                DateTime cellDate = DateTime(_focusedDate.year, _focusedDate.month, dayNumber);
                String key = "${cellDate.year}-${cellDate.month}-${cellDate.day}";

                List<PlanTask> tasks = dateTaskMap[key] ?? [];

                bool isInRange = cellDate.isAtSameMomentAs(widget.startDate) ||
                    cellDate.isAtSameMomentAs(widget.endDate) ||
                    (cellDate.isAfter(widget.startDate) && cellDate.isBefore(widget.endDate));

                return Container(
                  decoration: BoxDecoration(
                    color: isInRange ? const Color(0xFF1E1E1E) : const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isInRange ? Colors.white24 : Colors.white10,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: isInRange ? Colors.white70 : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: tasks.map((task) {
                            Color taskBgColor;
                            Color taskBorderColor;

                            if (task.status == 1) {
                              taskBgColor = Colors.green.withValues(alpha: 0.2);
                              taskBorderColor = Colors.green;
                            } else if (task.status == 2) {
                              taskBgColor = Colors.redAccent.withValues(alpha: 0.2);
                              taskBorderColor = Colors.redAccent;
                            } else if (task.status == 3) {
                              taskBgColor = Colors.amber.withValues(alpha: 0.2);
                              taskBorderColor = Colors.amber;
                            } else {
                              // İlk eklendiğinde boş / boyanmamış hali (dersin kendi renk temasına göre)
                              Color accent = _getSubjectColor(task.subject);
                              taskBgColor = accent.withValues(alpha: 0.2);
                              taskBorderColor = accent.withValues(alpha: 0.5);
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: taskBgColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: taskBorderColor),
                              ),
                              child: Text(
                                task.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                        ),
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
  }
}

// --- ORTAK AKTİF PLAN EKRANI ---

class PlanActiveScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final String programId;

  const PlanActiveScreen({super.key, required this.startDate, required this.endDate, required this.title, required this.programId});

  @override
  State<PlanActiveScreen> createState() => _PlanActiveScreenState();
}

class _PlanActiveScreenState extends State<PlanActiveScreen> {
  List<DayPlan> daysList = [];
  bool isFullView = true;
  int selectedDayIndex = 0;

  final List<String> dayNames = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];

  @override
  void initState() {
    super.initState();
    _initDays();
  }

  void _initDays() async {
    int totalDays = widget.endDate.difference(widget.startDate).inDays + 1;
    daysList = List.generate(totalDays, (i) {
      return DayPlan(date: widget.startDate.add(Duration(days: i)), tasks: []);
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    final allData = await UserDataService.fetchAllData();
    final String key = 'prog_data_${widget.programId}';
    final String? saved = allData[key];

    if (saved != null && saved.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(saved);
      setState(() {
        daysList = decoded.map((d) => DayPlan.fromJson(d)).toList();
      });
    }
  }

  Future<void> _saveData() async {
    final String key = 'prog_data_${widget.programId}';
    final String encoded = jsonEncode(daysList.map((d) => d.toJson()).toList());
    await UserDataService.saveModuleData(key, encoded);
  }

  double get overallProgress {
    int total = 0;
    int completed = 0;
    for (var d in daysList) {
      for (var t in d.tasks) {
        total++;
        if (t.status == 1) completed++;
      }
    }
    return total == 0 ? 0.0 : (completed / total);
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  String _getDayName(DateTime date) {
    return dayNames[date.weekday - 1];
  }

  Color _getSubjectColor(String subject) {
    return subjectMeta[subject]?['color'] ?? Colors.grey;
  }

  Future<String?> _showSubjectSelector(BuildContext context) async {
    TextEditingController searchCtrl = TextEditingController();
    List<String> keys = subjectMeta.keys.toList();
    List<String> filtered = List.from(keys);

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Ders Seç veya Yaz", style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            height: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Ders ara...",
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      filtered = keys.where((k) => k.toLowerCase().contains(val.toLowerCase())).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        if (searchCtrl.text.trim().isEmpty) return const SizedBox.shrink();
                        return ListTile(
                          title: Text("Özel Ekle: '${searchCtrl.text.trim()}'", style: const TextStyle(color: Colors.cyanAccent)),
                          onTap: () => Navigator.pop(ctx, searchCtrl.text.trim()),
                        );
                      }
                      String subject = filtered[index];
                      return ListTile(
                        title: Text(subject, style: const TextStyle(color: Colors.white)),
                        onTap: () => Navigator.pop(ctx, subject),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      ),
    );
  }

  // Rutin Ekleme Modalı (Artık Ekstra Detayları da İçeriyor)
  void _showRoutineModal() async {
    String? selectedSubject = await _showSubjectSelector(context);
    if (selectedSubject == null || selectedSubject.isEmpty || !context.mounted) return;

    String topic = "", time = "", testCount = "", questionCount = "", videoCount = "", note = "";
    List<bool> selectedDays = List.generate(daysList.length, (index) => false);
    bool selectAll = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Rutin Ekle ($selectedSubject)", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Konu Adı (*)", labelStyle: TextStyle(color: Colors.white54)),
                  onChanged: (v) => topic = v,
                ),
                Row(
                  children: [
                    Expanded(child: TextField(style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Saat (Sayısal)"), onChanged: (v) => time = v)),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Test Sayısı"), keyboardType: TextInputType.number, onChanged: (v) => testCount = v)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Soru Sayısı"), keyboardType: TextInputType.number, onChanged: (v) => questionCount = v)),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Video Sayısı"), keyboardType: TextInputType.number, onChanged: (v) => videoCount = v)),
                  ],
                ),
                TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Notlar"), maxLines: 2, onChanged: (v) => note = v),
                const SizedBox(height: 15),
                const Align(alignment: Alignment.centerLeft, child: Text("Uygulanacak Günler:", style: TextStyle(color: Colors.white70))),
                Wrap(
                  spacing: 5,
                  children: List.generate(daysList.length, (i) {
                    return FilterChip(
                      label: Text("${_getDayName(daysList[i].date).substring(0, 3)} (${daysList[i].date.day}/${daysList[i].date.month})"),
                      selected: selectedDays[i],
                      selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                      onSelected: (val) {
                        setModalState(() {
                          selectedDays[i] = val;
                          selectAll = !selectedDays.contains(false);
                        });
                      },
                    );
                  }),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: selectAll,
                      onChanged: (val) {
                        setModalState(() {
                          selectAll = val ?? false;
                          selectedDays = List.generate(daysList.length, (index) => selectAll);
                        });
                      },
                    ),
                    const Text("Tüm Günler", style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 50)),
                  onPressed: () {
                    if (topic.isNotEmpty) {
                      setState(() {
                        for (int i = 0; i < daysList.length; i++) {
                          if (selectedDays[i]) {
                            daysList[i].tasks.add(PlanTask(
                              id: UniqueKey().toString(),
                              subject: selectedSubject,
                              topic: topic,
                              time: time,
                              testCount: testCount,
                              questionCount: questionCount,
                              videoCount: videoCount,
                              note: note,
                            ));
                          }
                        }
                        _saveData();
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("Rutin Oluştur", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTaskModal(int dayIndex) async {
    String? selectedSub = await _showSubjectSelector(context);
    if (selectedSub == null || selectedSub.isEmpty || !context.mounted) return;

    String topic = "", time = "", testCount = "", questionCount = "", videoCount = "", note = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${_getDayName(daysList[dayIndex].date)} - $selectedSub Görev Ekle", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Konu Adı (*)"), onChanged: (v) => topic = v),
              Row(
                children: [
                  Expanded(child: TextField(style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Saat"), onChanged: (v) => time = v)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Test Sayısı"), keyboardType: TextInputType.number, onChanged: (v) => testCount = v)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Soru Sayısı"), keyboardType: TextInputType.number, onChanged: (v) => questionCount = v)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Video Sayısı"), keyboardType: TextInputType.number, onChanged: (v) => videoCount = v)),
                ],
              ),
              TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Notlar"), maxLines: 2, onChanged: (v) => note = v),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, minimumSize: const Size(double.infinity, 50)),
                onPressed: () {
                  if (topic.isNotEmpty) {
                    setState(() {
                      daysList[dayIndex].tasks.add(PlanTask(
                            id: UniqueKey().toString(),
                            subject: selectedSub,
                            topic: topic,
                            time: time,
                            testCount: testCount,
                            questionCount: questionCount,
                            videoCount: videoCount,
                            note: note,
                          ));
                      _saveData();
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Ekle", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayStats(int dayIndex) {
    final tasks = daysList[dayIndex].tasks;
    int total = tasks.length;
    if (total == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Gün Analizi", style: TextStyle(color: Colors.white)),
          content: const Text("Bu güne henüz görev eklenmemiş.", style: TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kapat"))],
        ),
      );
      return;
    }

    int tyt = 0, ayt = 0, say = 0, soz = 0;
    for (var t in tasks) {
      var meta = subjectMeta[t.subject];
      if (meta != null) {
        if (meta['exam']!.contains('TYT')) tyt++;
        if (meta['exam']!.contains('AYT')) ayt++;
        if (meta['type'] == 'Sayısal') say++;
        if (meta['type'] == 'Sözel') soz++;
      }
    }

    String p(int count) => ((count / total) * 100).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("${_getDayName(daysList[dayIndex].date)} Analizi", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📚 Toplam Görev: $total", style: const TextStyle(color: Colors.white70)),
            const Divider(color: Colors.white24),
            Text("🧮 Sayısal Ağırlık: %${p(say)}", style: const TextStyle(color: Colors.cyanAccent)),
            Text("📖 Sözel Ağırlık: %${p(soz)}", style: const TextStyle(color: Colors.yellowAccent)),
            const SizedBox(height: 10),
            Text("🎯 TYT Ağırlık: %${p(tyt)}", style: const TextStyle(color: Colors.orangeAccent)),
            Text("🚀 AYT Ağırlık: %${p(ayt)}", style: const TextStyle(color: Colors.purpleAccent)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kapat"))],
      ),
    );
  }

  Widget _buildTaskCard(PlanTask task, int dayIndex) {
    Color accent = _getSubjectColor(task.subject);
    Color bgColor = const Color(0xFF252525);
    
    if (task.status == 1) bgColor = Colors.green.withValues(alpha: 0.2);
    if (task.status == 2) bgColor = Colors.redAccent.withValues(alpha: 0.2);
    if (task.status == 3) bgColor = Colors.amber.withValues(alpha: 0.2);

    return LongPressDraggable<PlanTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.8, child: SizedBox(width: 200, child: _taskCardUI(task, accent, bgColor, dayIndex))),
      ),
      child: _taskCardUI(task, accent, bgColor, dayIndex),
    );
  }

  Widget _taskCardUI(PlanTask task, Color accent, Color bgColor, int dayIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), offset: const Offset(2, 4), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.drag_indicator, color: Colors.white38, size: 16),
                Expanded(child: Text(task.subject, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center)),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text("Emin misin?", style: TextStyle(color: Colors.white)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                daysList[dayIndex].tasks.removeWhere((t) => t.id == task.id);
                                _saveData();
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text("Sil"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                )
              ],
            ),
            const SizedBox(height: 6),
            Text(task.topic, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _statusBtn(task, 1, Icons.check_circle, Colors.green),
                    _statusBtn(task, 2, Icons.cancel, Colors.redAccent),
                    _statusBtn(task, 3, Icons.remove_circle, Colors.amber),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: Text("${task.subject} - Detay", style: const TextStyle(color: Colors.white)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Konu: ${task.topic}", style: const TextStyle(color: Colors.white70)),
                            if (task.time?.isNotEmpty ?? false) Text("Saat: ${task.time}", style: const TextStyle(color: Colors.white70)),
                            if (task.testCount?.isNotEmpty ?? false) Text("Test: ${task.testCount}", style: const TextStyle(color: Colors.white70)),
                            if (task.questionCount?.isNotEmpty ?? false) Text("Soru: ${task.questionCount}", style: const TextStyle(color: Colors.white70)),
                            if (task.videoCount?.isNotEmpty ?? false) Text("Video: ${task.videoCount}", style: const TextStyle(color: Colors.white70)),
                            if (task.note?.isNotEmpty ?? false) Text("Not: ${task.note}", style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _statusBtn(PlanTask task, int s, IconData icon, Color c) {
    return GestureDetector(
      onTap: () {
        setState(() {
          task.status = (task.status == s) ? 0 : s;
          _saveData();
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Icon(icon, color: task.status == s ? c : Colors.white24, size: 22),
      ),
    );
  }

  Widget _buildDayColumn(int index, double width) {
    DayPlan day = daysList[index];
    return DragTarget<PlanTask>(
      onAcceptWithDetails: (details) {
        PlanTask draggedTask = details.data;
        setState(() {
          for (var d in daysList) {
            d.tasks.removeWhere((t) => t.id == draggedTask.id);
          }
          daysList[index].tasks.add(draggedTask);
          _saveData();
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: width,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white12, width: isFullView ? 1 : 0)),
            color: candidateData.isNotEmpty ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(_getDayName(day.date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_formatDate(day.date), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.insert_chart_outlined, color: Colors.cyanAccent, size: 20),
                    onPressed: () => _showDayStats(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: day.tasks.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i < day.tasks.length) {
                      return _buildTaskCard(day.tasks[i], index);
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 36),
                            onPressed: () => _showAddTaskModal(index),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (daysList.isEmpty) return const Scaffold(backgroundColor: Color(0xFF121212));

    int percent = (overallProgress * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("${widget.title} (%$percent)"),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.tealAccent),
            tooltip: "Takvim Görünümü",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MonthlyOverviewScreen(
                    daysList: daysList,
                    startDate: widget.startDate,
                    endDate: widget.endDate,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.loop_rounded, color: Colors.pinkAccent),
            tooltip: "Rutin Ekle",
            onPressed: _showRoutineModal,
          )
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: overallProgress,
            backgroundColor: const Color(0xFF252525),
            color: Colors.greenAccent,
            minHeight: 6,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text("Tümünü Gör", style: TextStyle(color: Colors.white))),
                      ButtonSegment(value: false, label: Text("Gün Gün", style: TextStyle(color: Colors.white))),
                    ],
                    selected: {isFullView},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        isFullView = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      backgroundColor: const Color(0xFF252525),
                      selectedBackgroundColor: Colors.blueAccent.withValues(alpha: 0.3),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                if (!isFullView) ...[
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF252525)),
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: daysList[selectedDayIndex].date,
                        firstDate: widget.startDate,
                        lastDate: widget.endDate,
                      );
                      if (picked != null) {
                        int diff = picked.difference(widget.startDate).inDays;
                        setState(() => selectedDayIndex = diff);
                      }
                    },
                    child: Text(_formatDate(daysList[selectedDayIndex].date), style: const TextStyle(color: Colors.white)),
                  )
                ]
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: isFullView
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(daysList.length, (i) => _buildDayColumn(i, 220)),
                    ),
                  )
                : _buildDayColumn(selectedDayIndex, MediaQuery.of(context).size.width),
          ),
        ],
      ),
    );
  }
}