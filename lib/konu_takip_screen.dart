import 'dart:convert';
import 'package:flutter/material.dart';
import 'user_data_service.dart';

// --- VERİ MODELLERİ ---

class TopicItem {
  String id;
  String name;
  int status; 

  TopicItem({required this.id, required this.name, this.status = 0});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'status': status};

  factory TopicItem.fromJson(Map<String, dynamic> json) {
    return TopicItem(
      id: json['id'],
      name: json['name'],
      status: json['status'] ?? 0,
    );
  }
}

class SubjectItem {
  String id;
  String name;
  List<TopicItem> topics;

  SubjectItem({required this.id, required this.name, required this.topics});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'topics': topics.map((t) => t.toJson()).toList(),
      };

  factory SubjectItem.fromJson(Map<String, dynamic> json) {
    var topicsList = json['topics'] as List? ?? [];
    return SubjectItem(
      id: json['id'],
      name: json['name'],
      topics: topicsList.map((t) => TopicItem.fromJson(t)).toList(),
    );
  }
}

class AreaItem {
  String id;
  String name;
  List<SubjectItem> subjects;
  bool isCustomArea;

  AreaItem({required this.id, required this.name, required this.subjects, this.isCustomArea = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subjects': subjects.map((s) => s.toJson()).toList(),
        'isCustomArea': isCustomArea,
      };

  factory AreaItem.fromJson(Map<String, dynamic> json) {
    var subjectsList = json['subjects'] as List? ?? [];
    return AreaItem(
      id: json['id'],
      name: json['name'],
      isCustomArea: json['isCustomArea'] ?? false,
      subjects: subjectsList.map((s) => SubjectItem.fromJson(s)).toList(),
    );
  }

  double get progress {
    int total = 0;
    int learned = 0;
    for (var sub in subjects) {
      for (var top in sub.topics) {
        total++;
        if (top.status == 1) learned++;
      }
    }
    return total == 0 ? 0.0 : (learned / total);
  }
}

// --- ANA EKRAN (ALAN SEÇİMİ VE BUTONLAR) ---

class KonuTakipScreen extends StatefulWidget {
  const KonuTakipScreen({super.key});

  @override
  State<KonuTakipScreen> createState() => _KonuTakipScreenState();
}

class _KonuTakipScreenState extends State<KonuTakipScreen> {
  List<AreaItem> areas = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final allData = await UserDataService.fetchAllData();
    final String? savedData = allData['checklist_data_v2']; 

    if (savedData != null && savedData.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(savedData);
      areas = decoded.map((a) => AreaItem.fromJson(a)).toList();
    } else {
      areas = _getDefaultAreas();
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveData() async {
    final String encoded = jsonEncode(areas.map((a) => a.toJson()).toList());
    await UserDataService.saveModuleData('checklist_data_v2', encoded);
  }

  List<AreaItem> _getDefaultAreas() {
    return [
      AreaItem(id: "TYT", name: "TYT", subjects: _getTytSubjects()),
      AreaItem(id: "SOZEL", name: "Sözel", subjects: _getAytSozelSubjects()),
      AreaItem(id: "EA", name: "EA", subjects: _getAytEaSubjects()),
      AreaItem(id: "SAY", name: "SAY", subjects: _getAytSayisalSubjects()),
      AreaItem(id: "OZEL", name: "ÖZEL", subjects: [], isCustomArea: true),
    ];
  }

  List<SubjectItem> _getTytSubjects() {
    return [
      _createSubject("Türkçe", ["Sözcükte Anlam", "Cümlede Anlam", "Paragrafta Anlam", "Ses Bilgisi", "Yazım Kuralları", "Noktalama İşaretleri", "Sözcükte Yapı", "Sözcük Türleri", "İsimler", "Zamirler", "Sıfatlar", "Zarflar", "Edat – Bağlaç – Ünlem", "Fiil, Ek Fiil, Fiilimsi", "Sözcük Grupları", "Cümlenin Ögeleri", "Cümle Türleri", "Anlatım Bozukluğu"]),
      _createSubject("Tarih", ["Tarih ve Zaman", "İnsanlığın Doğuşu Ve İlk Uygarlıklar", "Orta Çağda Dünya ve Türkler", "İslam Medeniyetinin Doğuşu", "Türklerin İslamiyet’i Kabulü", "Yerleşme ve Devletleşme", "Dünya Gücü Osmanlı (1453-1595)", "Milli Mücadele", "Atatürkçülük ve Türk İnkılabı"]),
      _createSubject("Coğrafya", ["Doğa ve İnsan", "Dünya’nın Şekli ve Hareketleri", "Coğrafi Konum", "Harita Bilgisi", "Atmosfer ve Sıcaklık", "İklimler", "Basınç ve Rüzgarlar", "Doğal Afetler"]),
      _createSubject("Matematik", ["Temel Kavramlar", "Sayı Basamakları", "Rasyonel Sayılar", "Basit Eşitsizlikler", "Mutlak Değer", "Problemler", "Kümeler", "Fonksiyonlar", "Olasılık"]),
    ];
  }

  List<SubjectItem> _getAytSozelSubjects() {
    return [
      _createSubject("Edebiyat", ["Sözcükte Anlam", "Cümlede Anlam", "Paragrafta Anlam", "Şiir Bilgisi", "Söz Sanatları", "İslamiyet Öncesi Türk Edebiyatı", "Halk Edebiyatı", "Divan Edebiyatı", "Tanzimat Edebiyatı", "Milli Edebiyat", "Cumhuriyet Dönemi"]),
      _createSubject("Tarih 1", ["Tarih ve Zaman", "İlk ve Orta Çağlarda Türk Dünyası", "Dünya Gücü Osmanlı (1453-1595)", "Atatürkçülük ve Türk İnkılabı", "II. Dünya Savaşı"]),
      _createSubject("Coğrafya", ["Ekosistem Özellikleri", "Küresel İklim Değişikliği", "Şehirler ve Kırsal Yerleşmeler", "Türkiye’de Tarım, Sanayi, Maden", "Çevre Sorunları"]),
    ];
  }

  List<SubjectItem> _getAytEaSubjects() {
    return [
      _createSubject("Matematik", ["Fonksiyonlarda Uygulamalar", "Denklem ve Eşitsizlikler", "Trigonometri", "Logaritma", "Diziler", "Limit", "Türev", "İntegral"]),
      ..._getAytSozelSubjects(), 
    ];
  }

  List<SubjectItem> _getAytSayisalSubjects() {
    return [
      _createSubject("Matematik", ["Trigonometri", "Logaritma", "Diziler", "Limit", "Türev", "İntegral"]),
      _createSubject("Fizik", ["Vektörler", "Bağıl Hareket", "Newton'un Hareket Yasaları", "İş, Güç ve Enerji", "Atışlar", "Çembersel Hareket", "Modern Fizik"]),
      _createSubject("Kimya", ["Modern Atom Teorisi", "Gazlar", "Sıvı Çözeltiler", "Kimyasal Tepkimelerde Enerji", "Organik Kimya"]),
      _createSubject("Biyoloji", ["Sinir Sistemi", "Endokrin Sistem", "Duyu Organları", "Destek ve Hareket Sistemi", "Sindirim Sistemi", "Bitki Biyolojisi"]),
    ];
  }

  SubjectItem _createSubject(String name, List<String> topics) {
    return SubjectItem(
      id: UniqueKey().toString(),
      name: name,
      topics: topics.map((t) => TopicItem(id: UniqueKey().toString(), name: t)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) return const Scaffold(backgroundColor: Color(0xFF121212));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Konu Takip'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // EKSİK KONU BUTONU (Sağ Üstte)
            Align(
              alignment: Alignment.topRight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.yellowAccent, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  foregroundColor: Colors.yellowAccent,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EksikKonuSelectorScreen(areas: areas)),
                  );
                },
                child: const Text("Eksik konu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
            
            // OVAL BUTON LİSTESİ (Ortalanmış)
            Expanded(
              child: ListView.builder(
                itemCount: areas.length,
                itemBuilder: (context, index) {
                  return Align(
                    alignment: Alignment.center,
                    child: _buildOvalWaterFillButton(areas[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // OVAL SU DOLDURMA BUTONU MİMARİSİ
  Widget _buildOvalWaterFillButton(AreaItem area) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 70, // Elips şeklini vermek için sabit yükseklik
      width: MediaQuery.of(context).size.width * 0.65, // Ekranın %65'ini kaplasın
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChecklistDetailScreen(area: area, onSave: _saveData),
            ),
          ).then((_) => setState(() {})); 
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35), // Yüksekliğin tam yarısı mükemmel oval yapar
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Arka plan
              Container(color: const Color(0xFF1E1E1E)),
              // Su dolma efekti
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                heightFactor: area.progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade700, Colors.lightGreenAccent.withValues(alpha: 0.5)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              // Çerçeve ve Yazı
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: Colors.white, width: 2), // Tasarımdaki kalın siyah çerçeve yerine koyu temaya uygun beyaz
                ),
                child: Center(
                  child: Text(
                    area.name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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

// --- DETAY EKRANI (KONU LİSTESİ) ---

class ChecklistDetailScreen extends StatefulWidget {
  final AreaItem area;
  final VoidCallback onSave;

  const ChecklistDetailScreen({super.key, required this.area, required this.onSave});

  @override
  State<ChecklistDetailScreen> createState() => _ChecklistDetailScreenState();
}

class _ChecklistDetailScreenState extends State<ChecklistDetailScreen> {
  void _addCustomSubject() {
    TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Yeni Ders Ekle", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  widget.area.subjects.add(SubjectItem(id: UniqueKey().toString(), name: ctrl.text.trim(), topics: []));
                  widget.onSave();
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  void _addCustomTopic(SubjectItem subject) {
    TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("${subject.name} - Konu Ekle", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  subject.topics.add(TopicItem(id: UniqueKey().toString(), name: ctrl.text.trim()));
                  widget.onSave();
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(VoidCallback onConfirm, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Emin misin?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("$title silinecek. Bu işlem geri alınamaz.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text("Evet, Sil", style: TextStyle(color: Colors.white)),
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
        title: Text(widget.area.name),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (widget.area.isCustomArea)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  side: const BorderSide(color: Colors.pinkAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add, color: Colors.pinkAccent),
                label: const Text("YENİ DERS EKLE", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                onPressed: _addCustomSubject,
              ),
            ),
          ...widget.area.subjects.map((subject) => _buildSubjectTile(subject)),
        ],
      ),
    );
  }

  Widget _buildSubjectTile(SubjectItem subject) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        iconColor: Colors.pinkAccent,
        collapsedIconColor: Colors.white54,
        title: Row(
          children: [
            Expanded(child: Text(subject.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            if (widget.area.isCustomArea) ...[
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
                onPressed: () => _addCustomTopic(subject),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(() {
                  setState(() {
                    widget.area.subjects.remove(subject);
                    widget.onSave();
                  });
                }, subject.name),
              ),
            ]
          ],
        ),
        children: subject.topics.map((topic) {
          // Arka plan rengi belirleme
          Color bgColor = Colors.transparent;
          if (topic.status == 1) {
            bgColor = Colors.green.withValues(alpha: 0.25);
          } else if (topic.status == 2) bgColor = Colors.redAccent.withValues(alpha: 0.25);
          else if (topic.status == 3) bgColor = Colors.amber.withValues(alpha: 0.25);

          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: const Border(top: BorderSide(color: Colors.white12)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              title: Text(
                topic.name,
                style: TextStyle(
                  color: Colors.white,
                  decoration: topic.status == 1 ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.redAccent,
                  decorationThickness: 3.0,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusButton(topic, 1, Icons.check_circle, Colors.green),
                  _buildStatusButton(topic, 2, Icons.cancel, Colors.redAccent),
                  _buildStatusButton(topic, 3, Icons.remove_circle, Colors.amber),
                  if (widget.area.isCustomArea)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white24, size: 20),
                      onPressed: () => _confirmDelete(() {
                        setState(() {
                          subject.topics.remove(topic);
                          widget.onSave();
                        });
                      }, topic.name),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusButton(TopicItem topic, int statusVal, IconData icon, Color activeColor) {
    bool isActive = topic.status == statusVal;
    return IconButton(
      icon: Icon(icon, color: isActive ? activeColor : Colors.white24),
      iconSize: 26,
      onPressed: () {
        setState(() {
          topic.status = (topic.status == statusVal) ? 0 : statusVal;
          widget.onSave();
        });
      },
    );
  }
}

// --- EKSİK KONULAR SEÇİM EKRANI ---

class EksikKonuSelectorScreen extends StatelessWidget {
  final List<AreaItem> areas;

  const EksikKonuSelectorScreen({super.key, required this.areas});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Eksik/Unutulan - Alan Seç'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: areas.length,
          itemBuilder: (context, index) {
            final area = areas[index];
            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(area.name, style: const TextStyle(color: Colors.white, fontSize: 18)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EksikKonularListScreen(area: area),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- EKSİK KONULAR (SADECE OKUMA) LİSTESİ ---

class EksikKonularListScreen extends StatelessWidget {
  final AreaItem area;

  const EksikKonularListScreen({super.key, required this.area});

  @override
  Widget build(BuildContext context) {
    List<Widget> content = [];
    
    for (var subject in area.subjects) {
      var missingTopics = subject.topics.where((t) => t.status == 2 || t.status == 3).toList();
      
      if (missingTopics.isNotEmpty) {
        content.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
            child: Text(
              subject.name,
              style: const TextStyle(color: Colors.pinkAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
        
        for (var topic in missingTopics) {
          Color bgColor = topic.status == 2 ? Colors.redAccent.withValues(alpha: 0.25) : Colors.amber.withValues(alpha: 0.25);
          IconData icon = topic.status == 2 ? Icons.cancel : Icons.remove_circle;
          Color iconColor = topic.status == 2 ? Colors.redAccent : Colors.amber;

          content.add(
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: Icon(icon, color: iconColor),
                title: Text(topic.name, style: const TextStyle(color: Colors.white)),
              ),
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('${area.name} Eksikler'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      body: content.isEmpty
          ? const Center(
              child: Text(
                "Harika! Bu alanda eksik veya unutulan konu yok.",
                style: TextStyle(color: Colors.greenAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: content,
            ),
    );
  }
}