import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_data_service.dart';
import 'bamboo_economy.dart';
import 'banner_ad_widget.dart';

enum TimerMode { pomodoro, stopwatch, timer }

class PomodoroRecord {
  final String date;
  final int totalWorkSeconds;
  final int cycles;
  final bool isCompleted;

  PomodoroRecord({
    required this.date,
    required this.totalWorkSeconds,
    required this.cycles,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'totalWorkSeconds': totalWorkSeconds,
        'cycles': cycles,
        'isCompleted': isCompleted,
      };

  factory PomodoroRecord.fromJson(Map<String, dynamic> json) => PomodoroRecord(
        date: json['date'] ?? '',
        totalWorkSeconds: json['totalWorkSeconds'] ?? 0,
        cycles: json['cycles'] ?? 0,
        isCompleted: json['isCompleted'] ?? false,
      );
}

// --- GLOBAL YÖNETİCİ VE OVERLAY ---
class PomodoroManager {
  static final PomodoroManager _instance = PomodoroManager._internal();
  factory PomodoroManager() => _instance;
  PomodoroManager._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  TimerMode currentMode = TimerMode.pomodoro;

  // Pomodoro Değişkenleri
  int workMinutes = 25;
  int breakMinutes = 5;
  late int remainingSeconds = workMinutes * 60;
  bool isWorkTime = true;
  int completedCycles = 0;
  bool infiniteLoop = true;
  int targetCycles = 4;

  // Kronometre Değişkenleri
  int stopwatchSeconds = 0;

  // Zamanlayıcı Değişkenleri
  int timerHours = 0;
  int timerMinutes = 10;
  int timerSecondsInput = 0;
  late int timerRemainingSeconds = (timerHours * 3600) + (timerMinutes * 60) + timerSecondsInput;

  bool isRunning = false;
  Timer? _timer;

  bool continuousAlarm = true;
  String selectedSound = 'Melodi 1';
  final AudioPlayer audioPlayer = AudioPlayer();

  List<PomodoroRecord> records = [];
  List<VoidCallback> listeners = [];

  static OverlayEntry? _floatingOverlay;
  static Offset floatingPosition = const Offset(20, 100);

  int lastSavedPomodoroWorkedSeconds = 0;

  void addListener(VoidCallback listener) => listeners.add(listener);
  void removeListener(VoidCallback listener) => listeners.remove(listener);

  void notifyListeners() {
    for (var l in listeners) {
      l();
    }
  }

  Future<void> _updateStudyingStatus(bool isStudying) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
        'isStudying': isStudying,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _toggleFloatingBar(BuildContext context, bool show) {
    if (show) {
      if (_floatingOverlay == null) {
        _floatingOverlay = OverlayEntry(
          builder: (context) => const FloatingPomodoroWidget(),
        );
        try {
          Navigator.of(context, rootNavigator: true).overlay?.insert(_floatingOverlay!);
        } catch (_) {}
      }
    } else {
      _floatingOverlay?.remove();
      _floatingOverlay = null;
    }
  }

  void startTimer(BuildContext context) {
    if (isRunning) return;
    audioPlayer.stop();
    isRunning = true;
    _updateStudyingStatus(true);
    
    _toggleFloatingBar(context, true);
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentMode == TimerMode.stopwatch) {
        stopwatchSeconds++;
        notifyListeners();
      } else if (currentMode == TimerMode.timer) {
        if (timerRemainingSeconds > 0) {
          timerRemainingSeconds--;
          notifyListeners();
        } else {
          _playGlobalSound();
          _showGlobalSnackBar('Süre doldu! Zamanlayıcı bitti 🚀', Colors.pinkAccent);

          if (continuousAlarm) {
            _showGlobalAlarmPopup();
          }

          int initialSeconds = (timerHours * 3600) + (timerMinutes * 60) + timerSecondsInput;
          _saveRecordToHistory(navigatorKey.currentContext, initialSeconds, 1, true);

          _timer?.cancel();
          isRunning = false;
          _updateStudyingStatus(false);
          timerRemainingSeconds = initialSeconds;
          _toggleFloatingBar(navigatorKey.currentContext ?? context, false);
          notifyListeners();
        }
      } else {
        // Pomodoro Modu
        if (remainingSeconds > 0) {
          remainingSeconds--;
          notifyListeners();
        } else {
          _playGlobalSound();
          if (isWorkTime) {
            completedCycles++;
          }

          _showGlobalSnackBar(
            isWorkTime ? 'Çalışma bitti! Mola vakti ☕' : 'Mola bitti! Yeni çalışma zamanı 🚀',
            Colors.pinkAccent,
          );

          if (continuousAlarm) {
            _showGlobalAlarmPopup();
          }

          if (!infiniteLoop && isWorkTime && completedCycles >= targetCycles) {
            _timer?.cancel();
            int totalWorkedSeconds = (completedCycles * workMinutes * 60);
            int segmentSeconds = totalWorkedSeconds - lastSavedPomodoroWorkedSeconds;
            if (segmentSeconds > 0) {
              _saveRecordToHistory(navigatorKey.currentContext, totalWorkedSeconds, completedCycles, true);
            }

            isRunning = false;
            _updateStudyingStatus(false);
            isWorkTime = true;
            remainingSeconds = workMinutes * 60;
            completedCycles = 0;
            lastSavedPomodoroWorkedSeconds = 0;
            _toggleFloatingBar(navigatorKey.currentContext ?? context, false);
            notifyListeners();
            return;
          }

          isWorkTime = !isWorkTime;
          remainingSeconds = (isWorkTime ? workMinutes : breakMinutes) * 60;
          
          if (isWorkTime) {
            int totalWorkedSoFar = completedCycles * workMinutes * 60;
            int segmentSeconds = totalWorkedSoFar - lastSavedPomodoroWorkedSeconds;
            if (segmentSeconds > 0) {
              _saveRecordToHistory(navigatorKey.currentContext, segmentSeconds, 1, true);
              lastSavedPomodoroWorkedSeconds = totalWorkedSoFar;
            }
          }
          notifyListeners();
        }
      }
    });
  }

  void _saveRecordToHistory(BuildContext? context, int totalSeconds, int cycles, bool isCompleted) async {
    if (totalSeconds <= 0) return;
    
    int earnedCoins = 0;
    if (totalSeconds >= 360) {
      earnedCoins = ((totalSeconds * 10) / 3600).round();
      if (earnedCoins < 1) earnedCoins = 1;
    }

    if (earnedCoins > 0) {
      await BambooEconomy.addCoins(earnedCoins);
    }

    int workedMinutes = totalSeconds ~/ 60;
    if (workedMinutes > 0) {
      await BambooEconomy.addFocusMinutes(workedMinutes);
    }

    final ctx = context ?? navigatorKey.currentContext;
    if (ctx != null) {
      showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🎉', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Text('Tebrikler!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Odak seansını kaydettin!\n\n⏱️ Çalışma Süresi: ${_formatHistoryTimeStatic(totalSeconds)}\n🪙 Kazanılan Coin: +$earnedCoins\n${totalSeconds < 360 ? '\n(Not: 6 dakikadan az çalıştığın için coin kazanılmadı)' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Harika!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    String dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    records.insert(
      0,
      PomodoroRecord(
        date: dateStr,
        totalWorkSeconds: totalSeconds,
        cycles: cycles,
        isCompleted: isCompleted,
      ),
    );
    await _saveGlobalRecords();
    notifyListeners();
  }

  static String _formatHistoryTimeStatic(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;

    if (h > 0 && m > 0) return '${h}sa ${m}dk';
    if (h > 0) return '${h}sa';
    if (m > 0) return '${m}dk';
    return '${s}sn';
  }

  void _showGlobalSnackBar(String message, Color color) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showGlobalAlarmPopup() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Colors.pinkAccent, size: 28),
            SizedBox(width: 10),
            Text('Alarm Çalıyor!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text('Süre doldu! Alarmı susturmak için aşağıdaki butona tıklayın.', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              audioPlayer.stop();
              Navigator.pop(dialogContext);
            },
            child: const Text('Alarmı Sustur', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _playGlobalSound() async {
    try {
      String audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
      if (selectedSound == 'Melodi 2') {
        audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2870/2870-preview.mp3';
      } else if (selectedSound == 'Melodi 3') {
        audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2860/2860-preview.mp3';
      }

      if (continuousAlarm) {
        await audioPlayer.setReleaseMode(ReleaseMode.loop);
      } else {
        await audioPlayer.setReleaseMode(ReleaseMode.release);
      }
      await audioPlayer.play(UrlSource(audioUrl));
    } catch (_) {}
  }

  void pauseTimer(BuildContext? context) {
    audioPlayer.stop();
    _timer?.cancel();
    _updateStudyingStatus(false);
    isRunning = false;
    _toggleFloatingBar(context ?? navigatorKey.currentContext!, false);
    notifyListeners();
  }

  void resetTimer(BuildContext? context) {
    audioPlayer.stop();
    _timer?.cancel();
    _updateStudyingStatus(false);
    
    isRunning = false;
    isWorkTime = true;
    remainingSeconds = workMinutes * 60;
    stopwatchSeconds = 0;
    timerRemainingSeconds = (timerHours * 3600) + (timerMinutes * 60) + timerSecondsInput;
    completedCycles = 0;
    lastSavedPomodoroWorkedSeconds = 0;

    _toggleFloatingBar(context ?? navigatorKey.currentContext!, false);
    notifyListeners();
  }

  void completeOrFinishTimer(BuildContext? context) {
    audioPlayer.stop();
    _timer?.cancel();
    _updateStudyingStatus(false);

    final ctx = context ?? navigatorKey.currentContext;

    if (currentMode == TimerMode.stopwatch) {
      if (stopwatchSeconds > 0) {
        _saveRecordToHistory(ctx, stopwatchSeconds, 1, true);
      }
    } else if (currentMode == TimerMode.timer) {
      int initialSeconds = (timerHours * 3600) + (timerMinutes * 60) + timerSecondsInput;
      int elapsedSeconds = initialSeconds - timerRemainingSeconds;
      if (elapsedSeconds > 0) {
        _saveRecordToHistory(ctx, elapsedSeconds, 1, false);
      }
    } else if (currentMode == TimerMode.pomodoro) {
      int currentCycleWorked = isWorkTime ? (workMinutes * 60) - remainingSeconds : 0;
      int totalWorkedSoFar = (completedCycles * workMinutes * 60) + currentCycleWorked;
      int segmentSeconds = totalWorkedSoFar - lastSavedPomodoroWorkedSeconds;

      if (segmentSeconds > 0) {
        bool isSuccess = infiniteLoop ? true : (completedCycles >= targetCycles);
        _saveRecordToHistory(ctx, segmentSeconds, completedCycles > 0 ? completedCycles : 1, isSuccess);
      }
    }

    isRunning = false;
    isWorkTime = true;
    remainingSeconds = workMinutes * 60;
    stopwatchSeconds = 0;
    timerRemainingSeconds = (timerHours * 3600) + (timerMinutes * 60) + timerSecondsInput;
    completedCycles = 0;
    lastSavedPomodoroWorkedSeconds = 0;

    _toggleFloatingBar(ctx ?? navigatorKey.currentContext!, false);
    notifyListeners();
  }

  Future<void> loadGlobalRecords() async {
    try {
      final allData = await UserDataService.fetchAllData();
      final String? recordsString = allData['pomodoro_records'];
      if (recordsString != null) {
        final List<dynamic> decoded = jsonDecode(recordsString);
        records = decoded.map((item) => PomodoroRecord.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveGlobalRecords() async {
    final String encoded = jsonEncode(records.map((r) => r.toJson()).toList());
    await UserDataService.saveModuleData('pomodoro_records', encoded);
  }
}

// --- ANA EKRAN ---

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  final PomodoroManager manager = PomodoroManager();
  String? playingPreviewMelody;
  final AudioPlayer previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    manager.loadGlobalRecords();
    manager.addListener(_onManagerUpdate);
    BambooEconomy.getCoins();

    previewPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        if (mounted) setState(() => playingPreviewMelody = null);
      }
    });
  }

  @override
  void dispose() {
    manager.removeListener(_onManagerUpdate);
    previewPlayer.dispose();
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            manager.addListener(() {
              if (context.mounted) setDialogState(() {});
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.history_rounded, color: Colors.pinkAccent),
                  SizedBox(width: 8),
                  Text('Çalışma Geçmişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: SizedBox(
                width: 320,
                height: 380,
                child: manager.records.isEmpty
                    ? const Center(
                        child: Text(
                          'Henüz kayıt yok.\nÇalışmaya başla! 🚀',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: manager.records.length,
                        itemBuilder: (context, index) {
                          final rec = manager.records[index];
                          return Card(
                            color: const Color(0xFF2C2C2C),
                            elevation: 1,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                'Süre: ${_formatHistoryTime(rec.totalWorkSeconds)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              subtitle: Text(
                                'Tarih: ${rec.date}',
                                style: const TextStyle(fontSize: 10, color: Colors.white54),
                              ),
                              trailing: rec.isCompleted
                                  ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                                  : const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openSettingsDialog() {
    if (manager.currentMode == TimerMode.stopwatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kronometre serbest sayım olduğu için ayara ihtiyaç duymaz ⏱️')),
      );
      return;
    }

    if (manager.currentMode == TimerMode.pomodoro) {
      int tempWork = manager.workMinutes;
      int tempBreak = manager.breakMinutes;
      bool tempInfinite = manager.infiniteLoop;
      int tempTarget = manager.targetCycles;
      setState(() => playingPreviewMelody = null);

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> playPreview(String soundName) async {
                try {
                  String audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
                  if (soundName == 'Melodi 2') {
                    audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2870/2870-preview.mp3';
                  } else if (soundName == 'Melodi 3') {
                    audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2860/2860-preview.mp3';
                  }

                  if (playingPreviewMelody == soundName) {
                    await previewPlayer.stop();
                    setDialogState(() => playingPreviewMelody = null);
                    setState(() => playingPreviewMelody = null);
                  } else {
                    await previewPlayer.stop();
                    await previewPlayer.setReleaseMode(ReleaseMode.release);
                    await previewPlayer.play(UrlSource(audioUrl));
                    setDialogState(() => playingPreviewMelody = soundName);
                    setState(() => playingPreviewMelody = soundName);
                  }
                } catch (_) {}
              }

              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: const Text('Pomodoro Ayarları', style: TextStyle(color: Colors.white)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Çalışma Süresi: $tempWork Dakika', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      Slider(
                        value: tempWork.toDouble(),
                        min: 1,
                        max: 360,
                        divisions: 359,
                        activeColor: Colors.pinkAccent,
                        inactiveColor: Colors.white24,
                        label: '$tempWork dk',
                        onChanged: (val) {
                          setDialogState(() => tempWork = val.toInt());
                        },
                      ),
                      const SizedBox(height: 10),
                      Text('Mola Süresi: $tempBreak Dakika', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      Slider(
                        value: tempBreak.toDouble(),
                        min: 1,
                        max: 180,
                        divisions: 179,
                        activeColor: Colors.greenAccent,
                        inactiveColor: Colors.white24,
                        label: '$tempBreak dk',
                        onChanged: (val) {
                          setDialogState(() => tempBreak = val.toInt());
                        },
                      ),
                      const Divider(height: 20, color: Colors.white24),
                      Row(
                        children: [
                          const Text('Sonsuz Döngü', style: TextStyle(fontSize: 16, color: Colors.white)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showInfoTooltip(context, 'Sonsuz Döngü', 'Çalışma dan molaya geçiş otomatik olur.'),
                            child: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                          ),
                          const Spacer(),
                          Checkbox(
                            value: tempInfinite,
                            activeColor: Colors.pinkAccent,
                            checkColor: Colors.black,
                            onChanged: (val) {
                              setDialogState(() => tempInfinite = val ?? true);
                            },
                          ),
                        ],
                      ),
                      if (!tempInfinite) ...[
                        const SizedBox(height: 10),
                        Text('Hedef Etüt Sayısı: $tempTarget', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                        Slider(
                          value: tempTarget.toDouble(),
                          min: 1,
                          max: 20,
                          divisions: 19,
                          activeColor: Colors.cyanAccent,
                          inactiveColor: Colors.white24,
                          label: '$tempTarget Etüt',
                          onChanged: (val) {
                            setDialogState(() => tempTarget = val.toInt());
                          },
                        ),
                      ],
                      const Divider(height: 20, color: Colors.white24),
                      Row(
                        children: [
                          const Text('Sürekli Çal', style: TextStyle(fontSize: 16, color: Colors.white)),
                          const Spacer(),
                          Checkbox(
                            value: manager.continuousAlarm,
                            activeColor: Colors.pinkAccent,
                            checkColor: Colors.black,
                            onChanged: (val) {
                              setDialogState(() => manager.continuousAlarm = val ?? true);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text('Alarm Melodisi:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      ...['Melodi 1', 'Melodi 2', 'Melodi 3'].map((sound) {
                        bool isPlayingThis = playingPreviewMelody == sound;
                        return RadioListTile<String>(
                          dense: true,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sound, style: const TextStyle(color: Colors.white)),
                              IconButton(
                                icon: Icon(
                                  isPlayingThis ? Icons.stop_circle : Icons.play_circle_fill,
                                  color: isPlayingThis ? Colors.pinkAccent : Colors.amberAccent,
                                ),
                                onPressed: () => playPreview(sound),
                              ),
                            ],
                          ),
                          value: sound,
                          groupValue: manager.selectedSound,
                          activeColor: Colors.pinkAccent,
                          onChanged: (val) {
                            setDialogState(() => manager.selectedSound = val ?? 'Melodi 1');
                          },
                        );
                      }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      previewPlayer.stop();
                      setState(() => playingPreviewMelody = null);
                      Navigator.pop(context);
                    },
                    child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                    onPressed: () {
                      previewPlayer.stop();
                      setState(() {
                        playingPreviewMelody = null;
                        manager.workMinutes = tempWork;
                        manager.breakMinutes = tempBreak;
                        manager.infiniteLoop = tempInfinite;
                        manager.targetCycles = tempTarget;
                        if (!manager.isRunning) {
                          manager.remainingSeconds = manager.workMinutes * 60;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      int tempHours = manager.timerHours;
      int tempMinutes = manager.timerMinutes;
      int tempSeconds = manager.timerSecondsInput;
      setState(() => playingPreviewMelody = null);

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> playPreview(String soundName) async {
                try {
                  String audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
                  if (soundName == 'Melodi 2') {
                    audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2870/2870-preview.mp3';
                  } else if (soundName == 'Melodi 3') {
                    audioUrl = 'https://assets.mixkit.co/active_storage/sfx/2860/2860-preview.mp3';
                  }

                  if (playingPreviewMelody == soundName) {
                    await previewPlayer.stop();
                    setDialogState(() => playingPreviewMelody = null);
                    setState(() => playingPreviewMelody = null);
                  } else {
                    await previewPlayer.stop();
                    await previewPlayer.setReleaseMode(ReleaseMode.release);
                    await previewPlayer.play(UrlSource(audioUrl));
                    setDialogState(() => playingPreviewMelody = soundName);
                    setState(() => playingPreviewMelody = soundName);
                  }
                } catch (_) {}
              }

              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: const Text('Zamanlayıcı Ayarları', style: TextStyle(color: Colors.white)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saat: $tempHours', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      Slider(
                        value: tempHours.toDouble(),
                        min: 0,
                        max: 12,
                        divisions: 12,
                        activeColor: Colors.pinkAccent,
                        inactiveColor: Colors.white24,
                        label: '$tempHours sa',
                        onChanged: (val) => setDialogState(() => tempHours = val.toInt()),
                      ),
                      Text('Dakika: $tempMinutes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      Slider(
                        value: tempMinutes.toDouble(),
                        min: 0,
                        max: 59,
                        divisions: 59,
                        activeColor: Colors.pinkAccent,
                        inactiveColor: Colors.white24,
                        label: '$tempMinutes dk',
                        onChanged: (val) => setDialogState(() => tempMinutes = val.toInt()),
                      ),
                      Text('Saniye: $tempSeconds', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      Slider(
                        value: tempSeconds.toDouble(),
                        min: 0,
                        max: 59,
                        divisions: 59,
                        activeColor: Colors.pinkAccent,
                        inactiveColor: Colors.white24,
                        label: '$tempSeconds sn',
                        onChanged: (val) => setDialogState(() => tempSeconds = val.toInt()),
                      ),
                      const Divider(height: 20, color: Colors.white24),
                      Row(
                        children: [
                          const Text('Sürekli Çal', style: TextStyle(fontSize: 16, color: Colors.white)),
                          const Spacer(),
                          Checkbox(
                            value: manager.continuousAlarm,
                            activeColor: Colors.pinkAccent,
                            checkColor: Colors.black,
                            onChanged: (val) => setDialogState(() => manager.continuousAlarm = val ?? true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Alarm Melodisi:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      ...['Melodi 1', 'Melodi 2', 'Melodi 3'].map((sound) {
                        bool isPlayingThis = playingPreviewMelody == sound;
                        return RadioListTile<String>(
                          dense: true,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sound, style: const TextStyle(color: Colors.white)),
                              IconButton(
                                icon: Icon(
                                  isPlayingThis ? Icons.stop_circle : Icons.play_circle_fill,
                                  color: isPlayingThis ? Colors.pinkAccent : Colors.amberAccent,
                                ),
                                onPressed: () => playPreview(sound),
                              ),
                            ],
                          ),
                          value: sound,
                          groupValue: manager.selectedSound,
                          activeColor: Colors.pinkAccent,
                          onChanged: (val) => setDialogState(() => manager.selectedSound = val ?? 'Melodi 1'),
                        );
                      }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      previewPlayer.stop();
                      setState(() => playingPreviewMelody = null);
                      Navigator.pop(context);
                    },
                    child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                    onPressed: () {
                      previewPlayer.stop();
                      setState(() {
                        playingPreviewMelody = null;
                        manager.timerHours = tempHours;
                        manager.timerMinutes = tempMinutes;
                        manager.timerSecondsInput = tempSeconds;
                        int totalSecs = (tempHours * 3600) + (tempMinutes * 60) + tempSeconds;
                        if (totalSecs < 1) totalSecs = 60;
                        if (!manager.isRunning) {
                          manager.timerRemainingSeconds = totalSecs;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  void _showInfoTooltip(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatHistoryTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;

    if (h > 0 && m > 0) return '${h}sa ${m}dk';
    if (h > 0) return '${h}sa';
    if (m > 0) return '${m}dk';
    return '${s}sn';
  }

  @override
  Widget build(BuildContext context) {
    int displaySeconds = 0;
    if (manager.currentMode == TimerMode.pomodoro) {
      displaySeconds = manager.remainingSeconds;
    } else if (manager.currentMode == TimerMode.stopwatch) {
      displaySeconds = manager.stopwatchSeconds;
    } else {
      displaySeconds = manager.timerRemainingSeconds;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Odak & Pomodoro'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: BambooEconomy.coinNotifier,
            builder: (context, coins, child) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amberAccent, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        '$coins',
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.amberAccent),
            onPressed: _showHistoryDialog,
            tooltip: 'Geçmişi Gör',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton('Pomodoro', TimerMode.pomodoro),
                    _buildModeButton('Kronometre', TimerMode.stopwatch),
                    _buildModeButton('Zamanlayıcı', TimerMode.timer),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openSettingsDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.7), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.settings, color: Colors.pinkAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ayarlar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.pinkAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: manager.currentMode == TimerMode.pomodoro
                        ? (manager.isWorkTime ? Colors.pinkAccent : Colors.greenAccent)
                        : (manager.currentMode == TimerMode.stopwatch ? Colors.blueAccent : Colors.cyanAccent),
                    width: 6,
                  ),
                  color: const Color(0xFF1E1E1E),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      manager.currentMode == TimerMode.pomodoro
                          ? (manager.isWorkTime ? 'ÇALIŞMA VAKTİ' : 'MOLA VAKTİ')
                          : (manager.currentMode == TimerMode.stopwatch ? 'KRONOMETRE' : 'ZAMANLAYICI'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: manager.currentMode == TimerMode.pomodoro
                            ? (manager.isWorkTime ? Colors.pinkAccent : Colors.greenAccent)
                            : (manager.currentMode == TimerMode.stopwatch ? Colors.blueAccent : Colors.cyanAccent),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatTime(displaySeconds),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (manager.currentMode == TimerMode.pomodoro && !manager.infiniteLoop) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${manager.completedCycles} / ${manager.targetCycles} Etüt',
                        style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: manager.isRunning
                        ? () => setState(() => manager.pauseTimer(context))
                        : () => setState(() => manager.startTimer(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: manager.isRunning ? Colors.orangeAccent : Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      manager.isRunning ? 'Durdur' : 'Başlat',
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 15),
                  OutlinedButton(
                    onPressed: () => setState(() => manager.completeOrFinishTimer(context)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      side: const BorderSide(color: Colors.greenAccent, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Bitir & Kaydet',
                      style: TextStyle(fontSize: 14, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => manager.resetTimer(context)),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                    tooltip: 'İptal Et / Sıfırla (Kayıt Almaz)',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: BannerAdWidget(),
      ),
    );
  }

  Widget _buildModeButton(String title, TimerMode mode) {
    bool isSelected = manager.currentMode == mode;
    return GestureDetector(
      onTap: () {
        if (!manager.isRunning) {
          setState(() {
            manager.currentMode = mode;
            if (mode == TimerMode.timer) {
              manager.timerRemainingSeconds = (manager.timerHours * 3600) + (manager.timerMinutes * 60) + manager.timerSecondsInput;
              if (manager.timerRemainingSeconds < 1) manager.timerRemainingSeconds = 600;
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çalışma devam ederken mod değiştiremezsin! Önce durdur.')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.pinkAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class FloatingPomodoroWidget extends StatefulWidget {
  const FloatingPomodoroWidget({super.key});

  @override
  State<FloatingPomodoroWidget> createState() => _FloatingPomodoroWidgetState();
}

class _FloatingPomodoroWidgetState extends State<FloatingPomodoroWidget> {
  @override
  void initState() {
    super.initState();
    PomodoroManager().addListener(_updateState);
  }

  @override
  void dispose() {
    PomodoroManager().removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final manager = PomodoroManager();
    if (!manager.isRunning) return const SizedBox.shrink();

    Size screenSize = MediaQuery.of(context).size;
    int displaySeconds = 0;
    if (manager.currentMode == TimerMode.pomodoro) {
      displaySeconds = manager.remainingSeconds;
    } else if (manager.currentMode == TimerMode.stopwatch) {
      displaySeconds = manager.stopwatchSeconds;
    } else {
      displaySeconds = manager.timerRemainingSeconds;
    }

    return Positioned(
      left: PomodoroManager.floatingPosition.dx,
      top: PomodoroManager.floatingPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            double newX = PomodoroManager.floatingPosition.dx + details.delta.dx;
            double newY = PomodoroManager.floatingPosition.dy + details.delta.dy;

            newX = newX.clamp(10.0, screenSize.width - 150.0);
            newY = newY.clamp(40.0, screenSize.height - 100.0);

            PomodoroManager.floatingPosition = Offset(newX, newY);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1E1E1E),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sayaç Kontrol', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      Text(_formatTime(displaySeconds), style: const TextStyle(color: Colors.pinkAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                            onPressed: () {
                              manager.pauseTimer(null);
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.pause),
                            label: const Text('Durdur'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                            onPressed: () {
                              Navigator.pop(ctx);
                              manager.completeOrFinishTimer(null);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Bitir & Kaydet'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                           manager.resetTimer(null);
                           Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        label: const Text('Sıfırla / Çöpe At', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.pinkAccent, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded, color: Colors.pinkAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(displaySeconds),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}