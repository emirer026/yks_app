import 'package:flutter/material.dart';
import 'dart:math';
import 'user_data_service.dart';
import 'bamboo_economy.dart';
import 'pomodoro_screen.dart';
import 'dart:convert';

class BambooScreen extends StatefulWidget {
  const BambooScreen({super.key});

  @override
  State<BambooScreen> createState() => _BambooScreenState();
}

class _BambooScreenState extends State<BambooScreen> {
  int _totalFocusMinutes = 0;
  int _coins = 0;
  int _waterCount = 0;
  int _seedCount = 0;
  int _nameTagCount = 0;
  List<double> _bambooHeights = [0.0];
  List<String> _bambooNames = ['Bambu #1'];
  List<String> _bambooColorKeys = ['greenAccent'];
  int _selectedIndex = 0;
  List<String> _unlockedColors = ['greenAccent'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await UserDataService.fetchAllData();
    final focusMins = data['bamboo_focus_minutes'] ?? 0;
    final coins = data['bamboo_coins'] ?? 0;
    final water = data['bamboo_water_count'] ?? 0;
    final seeds = data['bamboo_seeds_count'] ?? 0;
    final nameTags = data['bamboo_name_tags_count'] ?? 0;
    final globalActiveColorKey = data['bamboo_active_color'] ?? 'greenAccent';
    final unlocked = await BambooEconomy.getUnlockedColors();

    List<double> heights = [0.0];
    if (data['bamboo_heights_list'] != null) {
      try {
        List<dynamic> decoded = jsonDecode(data['bamboo_heights_list']);
        heights = decoded.map((e) => (e as num).toDouble()).toList();
      } catch (_) {}
    } else if (data['bamboo_height'] != null) {
      heights = [(data['bamboo_height'] as num).toDouble()];
    }

    List<String> names = [];
    if (data['bamboo_names_list'] != null) {
      try {
        List<dynamic> decoded = jsonDecode(data['bamboo_names_list']);
        names = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    while (names.length < heights.length) {
      names.add('Bambu #${names.length + 1}');
    }

    List<String> colorKeys = [];
    if (data['bamboo_colors_list'] != null) {
      try {
        List<dynamic> decoded = jsonDecode(data['bamboo_colors_list']);
        colorKeys = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    while (colorKeys.length < heights.length) {
      colorKeys.add(globalActiveColorKey);
    }

    setState(() {
      _totalFocusMinutes = focusMins;
      _coins = coins;
      _waterCount = water;
      _seedCount = seeds;
      _nameTagCount = nameTags;
      _bambooHeights = heights.isNotEmpty ? heights : [0.0];
      _bambooNames = names.isNotEmpty ? names : ['Bambu #1'];
      _bambooColorKeys = colorKeys.isNotEmpty ? colorKeys : ['greenAccent'];
      if (_selectedIndex >= _bambooHeights.length) {
        _selectedIndex = 0;
      }
      _unlockedColors = unlocked;
    });
  }

  Future<void> _saveData() async {
    await UserDataService.saveModuleData('bamboo_focus_minutes', _totalFocusMinutes);
    await UserDataService.saveModuleData('bamboo_coins', _coins);
    await UserDataService.saveModuleData('bamboo_water_count', _waterCount);
    await UserDataService.saveModuleData('bamboo_seeds_count', _seedCount);
    await UserDataService.saveModuleData('bamboo_name_tags_count', _nameTagCount);
    await UserDataService.saveModuleData('bamboo_heights_list', jsonEncode(_bambooHeights));
    await UserDataService.saveModuleData('bamboo_names_list', jsonEncode(_bambooNames));
    await UserDataService.saveModuleData('bamboo_colors_list', jsonEncode(_bambooColorKeys));
  }

  void _goToPomodoro() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PomodoroScreen()),
    );
    _loadData();
  }

  Color _getColorFromKey(String key) {
    switch (key) {
      case 'cyanAccent': return Colors.cyanAccent;
      case 'pinkAccent': return Colors.pinkAccent;
      case 'amberAccent': return Colors.amberAccent;
      case 'purpleAccent': return Colors.purpleAccent;
      default: return Colors.greenAccent;
    }
  }

  void _openColorPickerBottomSheet() {
    final Map<String, Map<String, dynamic>> colorMap = {
      'greenAccent': {'name': 'Neon Yeşil', 'color': Colors.greenAccent},
      'cyanAccent': {'name': 'Cyber Mavi', 'color': Colors.cyanAccent},
      'pinkAccent': {'name': 'Neon Pembe', 'color': Colors.pinkAccent},
      'amberAccent': {'name': 'Solar Altın', 'color': Colors.amberAccent},
      'purpleAccent': {'name': 'Mor Işık', 'color': Colors.purpleAccent},
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎨 "${_bambooNames[_selectedIndex]}" Rengini Değiştir',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bu işlem sadece seçtiğiniz bambuyu etkiler!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ...colorMap.entries.map((entry) {
                  String key = entry.key;
                  String name = entry.value['name'];
                  Color color = entry.value['color'];
                  bool isUnlocked = _unlockedColors.contains(key);
                  bool isActive = _bambooColorKeys[_selectedIndex] == key;

                  return Opacity(
                    opacity: isUnlocked ? 1.0 : 0.4,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isActive ? color : Colors.white12, width: isActive ? 2 : 1),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: isUnlocked
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isActive ? color : Colors.white24,
                                  foregroundColor: isActive ? Colors.black : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _bambooColorKeys[_selectedIndex] = key;
                                  });
                                  _saveData();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${_bambooNames[_selectedIndex]} için $name uygulandı! ✨'), backgroundColor: color),
                                  );
                                },
                                child: Text(isActive ? 'Aktif' : 'Seç', style: const TextStyle(fontWeight: FontWeight.bold)),
                              )
                            : const Text('Kilitli 🔒', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _waterBamboo() async {
    if (_waterCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeterli suyun yok! Marketten su damlası almalısın. 💧'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await BambooEconomy.useWater();

    double currentHeight = _bambooHeights[_selectedIndex];

    double luckRoll = pow(Random().nextDouble(), 3.2).toDouble(); 
    double growth = 1.0 + (luckRoll * 49.0);
    growth = growth.clamp(1.0, 50.0);

    double newHeight = currentHeight + growth;

    setState(() {
      _waterCount--;
      _bambooHeights[_selectedIndex] = newHeight;
    });
    _saveData();

    int rarityPercent = ((50.0 - growth) / 49.0 * 100).toInt().clamp(1, 99);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🌿', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text('Bambu Sulandı!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zarları attın ve sular toprakla buluştu!', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📈 Büyüme Miktarı: +${growth.toInt()} cm', style: const TextStyle(color: Colors.greenAccent, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('🎲 Şans / Nadirlik: %$rarityPercent', style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('📏 Bambunun Yeni Boyu: ${newHeight.toInt()} cm', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ],
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

  void _plantSeed() async {
    if (_seedCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeterli tohumun yok! Marketten bambu tohumu almalısın. 🌰'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await BambooEconomy.useSeed();

    setState(() {
      _seedCount--;
      _bambooHeights.add(0.0);
      _bambooNames.add('Bambu #${_bambooHeights.length}');
      _bambooColorKeys.add('greenAccent');
      _selectedIndex = _bambooHeights.length - 1;
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yeni tohum ekildi! 🌱'),
        backgroundColor: Colors.greenAccent,
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _openNameTagDialog() {
    if (_nameTagCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İsim Etiketin yok! Marketten 50 Coine satın alabilirsin. 🏷️'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    TextEditingController nameController = TextEditingController(text: _bambooNames[_selectedIndex]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Bambu İsmini Değiştir', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Yeni isim girin',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _nameTagCount--;
                  _bambooNames[_selectedIndex] = nameController.text.trim();
                });
                await UserDataService.saveModuleData('bamboo_name_tags_count', _nameTagCount);
                _saveData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bambu ismi başarıyla güncellendi! ✨'), backgroundColor: Colors.greenAccent),
                );
              }
            },
            child: const Text('Uygula', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTotalFocus(int totalMins) {
    if (totalMins < 60) {
      return '$totalMins dk';
    }
    int hours = totalMins ~/ 60;
    int mins = totalMins % 60;
    if (mins == 0) {
      return '$hours saat';
    }
    return '$hours sa ${mins}dk';
  }

  @override
  Widget build(BuildContext context) {
    Color currentNeonColor = _bambooColorKeys.isNotEmpty && _selectedIndex < _bambooColorKeys.length
        ? _getColorFromKey(_bambooColorKeys[_selectedIndex])
        : Colors.greenAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Bambu Ormanı (Neon Odak)'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_rounded, color: Colors.cyanAccent),
            tooltip: 'Seçili Bambu Rengini Değiştir',
            onPressed: _openColorPickerBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.store_rounded, color: Colors.amberAccent),
            tooltip: 'Market',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BambooEconomyScreen()),
              );
              _loadData();
            },
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
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
                  ValueListenableBuilder<int>(
                    valueListenable: BambooEconomy.coinNotifier,
                    builder: (context, coins, child) {
                      return Text(
                        '$coins',
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Toplam Odak', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          _formatTotalFocus(_totalFocusMinutes),
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Colors.white24),
                    Column(
                      children: [
                        const Text('Seçili Bambu Boyu', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('${_bambooHeights[_selectedIndex].toInt()} cm', style: const TextStyle(color: Colors.amberAccent, fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 460,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(_bambooHeights.length, (index) {
                            double height = _bambooHeights[index];
                            bool isSelected = _selectedIndex == index;
                            int segmentCount = (height / 30).floor().clamp(0, 50);
                            String bambooName = index < _bambooNames.length ? _bambooNames[index] : 'Bambu #${index + 1}';
                            Color bambooColor = index < _bambooColorKeys.length 
                                ? _getColorFromKey(_bambooColorKeys[index]) 
                                : Colors.greenAccent;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                width: 120,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isSelected)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: bambooColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: bambooColor),
                                            ),
                                            child: Text(
                                              'Seçili',
                                              style: TextStyle(color: bambooColor, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: _openNameTagDialog,
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.amberAccent.withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.amberAccent),
                                              ),
                                              child: const Icon(Icons.edit, color: Colors.amberAccent, size: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    SizedBox(
                                      height: 380 + (height > 300 ? height - 300 : 0),
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          Positioned(
                                            bottom: 0,
                                            child: Container(
                                              width: 120,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3E2723),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isSelected ? bambooColor : Colors.white24,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isSelected ? bambooColor.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.5),
                                                    blurRadius: isSelected ? 10 : 4,
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: Text(
                                                      bambooName,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${height.toInt()} cm',
                                                    style: TextStyle(
                                                      color: isSelected ? bambooColor : Colors.amberAccent,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (height > 0)
                                            Positioned(
                                              bottom: 52,
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 500),
                                                width: 26,
                                                height: height,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [bambooColor.withValues(alpha: 0.7), bambooColor],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: bambooColor.withValues(alpha: 0.6),
                                                      blurRadius: isSelected ? 25 : 15,
                                                      spreadRadius: isSelected ? 4 : 2,
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: List.generate(
                                                    segmentCount,
                                                    (segIndex) => Container(
                                                      height: 3,
                                                      width: 26,
                                                      decoration: BoxDecoration(
                                                        color: Colors.black45,
                                                        boxShadow: [
                                                          BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 4),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.withValues(alpha: 0.2),
                          foregroundColor: Colors.amberAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.amberAccent),
                          ),
                        ),
                        icon: const Text('💧', style: TextStyle(fontSize: 18)),
                        label: Text('Sula (Hak: $_waterCount)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        onPressed: _waterBamboo,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          foregroundColor: Colors.greenAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.greenAccent),
                          ),
                        ),
                        icon: const Text('🌰', style: TextStyle(fontSize: 18)),
                        label: Text('Tohum (Hak: $_seedCount)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        onPressed: _plantSeed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentNeonColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 8,
                    shadowColor: currentNeonColor.withValues(alpha: 0.6),
                  ),
                  onPressed: _goToPomodoro,
                  child: const Text(
                    '🚀 Odaklan & Coin Kazan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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