import 'package:flutter/material.dart';
import 'user_data_service.dart';
import 'dart:convert';

class BambooEconomy {
  static final ValueNotifier<int> coinNotifier = ValueNotifier<int>(0);

  static Future<int> getCoins() async {
    final data = await UserDataService.fetchAllData();
    int coins = data['bamboo_coins'] ?? 0;
    coinNotifier.value = coins;
    return coins;
  }

  static Future<void> addCoins(int amount) async {
    final current = await getCoins();
    int newTotal = current + amount;
    await UserDataService.saveModuleData('bamboo_coins', newTotal);
    coinNotifier.value = newTotal;
  }

  static Future<void> spendCoins(int amount) async {
    final current = await getCoins();
    int newTotal = (current - amount).clamp(0, 999999);
    await UserDataService.saveModuleData('bamboo_coins', newTotal);
    coinNotifier.value = newTotal;
  }

  static Future<int> getWaterCount() async {
    final data = await UserDataService.fetchAllData();
    return data['bamboo_water_count'] ?? 0;
  }

  static Future<void> useWater() async {
    final current = await getWaterCount();
    if (current > 0) {
      await UserDataService.saveModuleData('bamboo_water_count', current - 1);
    }
  }

  static Future<int> getSeedCount() async {
    final data = await UserDataService.fetchAllData();
    return data['bamboo_seeds_count'] ?? 0;
  }

  static Future<void> useSeed() async {
    final current = await getSeedCount();
    if (current > 0) {
      await UserDataService.saveModuleData('bamboo_seeds_count', current - 1);
    }
  }

  // İsim Etiketi Kartı (Tag) Sayısı
  static Future<int> getNameTagCount() async {
    final data = await UserDataService.fetchAllData();
    return data['bamboo_name_tags_count'] ?? 0;
  }

  static Future<void> useNameTag() async {
    final current = await getNameTagCount();
    if (current > 0) {
      await UserDataService.saveModuleData('bamboo_name_tags_count', current - 1);
    }
  }

  static Future<int> getFocusMinutes() async {
    final data = await UserDataService.fetchAllData();
    return data['bamboo_focus_minutes'] ?? 0;
  }

  static Future<void> addFocusMinutes(int minutes) async {
    final current = await getFocusMinutes();
    await UserDataService.saveModuleData('bamboo_focus_minutes', current + minutes);
  }

  static Future<String> getActiveColor() async {
    final data = await UserDataService.fetchAllData();
    return data['bamboo_active_color'] ?? 'greenAccent';
  }

  static Future<void> setActiveColor(String colorKey) async {
    await UserDataService.saveModuleData('bamboo_active_color', colorKey);
  }

  static Future<List<String>> getUnlockedColors() async {
    final data = await UserDataService.fetchAllData();
    final raw = data['bamboo_unlocked_colors'];
    if (raw == null) return ['greenAccent'];
    try {
      List<dynamic> decoded = jsonDecode(raw);
      return decoded.cast<String>();
    } catch (_) {
      return ['greenAccent'];
    }
  }

  static Future<void> unlockColor(String colorKey) async {
    final unlocked = await getUnlockedColors();
    if (!unlocked.contains(colorKey)) {
      unlocked.add(colorKey);
      await UserDataService.saveModuleData('bamboo_unlocked_colors', jsonEncode(unlocked));
    }
  }
}

class BambooEconomyScreen extends StatefulWidget {
  const BambooEconomyScreen({super.key});

  @override
  State<BambooEconomyScreen> createState() => _BambooEconomyScreenState();
}

class _BambooEconomyScreenState extends State<BambooEconomyScreen> {
  int _coins = 0;
  int _waterCount = 0;
  int _seedCount = 0;
  int _nameTagCount = 0;
  String _activeColor = 'greenAccent';
  List<String> _unlockedColors = ['greenAccent'];

  final List<Map<String, dynamic>> _colorSkins = [
    {'key': 'greenAccent', 'name': 'Neon Yeşil', 'color': Colors.greenAccent, 'cost': 0},
    {'key': 'cyanAccent', 'name': 'Cyber Mavi', 'color': Colors.cyanAccent, 'cost': 100},
    {'key': 'pinkAccent', 'name': 'Neon Pembe', 'color': Colors.pinkAccent, 'cost': 150},
    {'key': 'amberAccent', 'name': 'Solar Altın', 'color': Colors.amberAccent, 'cost': 200},
    {'key': 'purpleAccent', 'name': 'Mor Işık', 'color': Colors.purpleAccent, 'cost': 250},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    BambooEconomy.coinNotifier.addListener(_onCoinChanged);
  }

  @override
  void dispose() {
    BambooEconomy.coinNotifier.removeListener(_onCoinChanged);
    super.dispose();
  }

  void _onCoinChanged() {
    if (mounted) {
      setState(() {
        _coins = BambooEconomy.coinNotifier.value;
      });
    }
  }

  Future<void> _loadData() async {
    final coins = await BambooEconomy.getCoins();
    final data = await UserDataService.fetchAllData();
    final active = await BambooEconomy.getActiveColor();
    final unlocked = await BambooEconomy.getUnlockedColors();

    setState(() {
      _coins = coins;
      _waterCount = data['bamboo_water_count'] ?? 0;
      _seedCount = data['bamboo_seeds_count'] ?? 0;
      _nameTagCount = data['bamboo_name_tags_count'] ?? 0;
      _activeColor = active;
      _unlockedColors = unlocked;
    });
  }

  // Artık buradaki her kayıt işlemi, UserDataService üzerinden otomatik olarak 
  // 'bamboo_' prefix'ine sahip olduğu için doğrudan kullanıcının mailine (Firebase UID'sine) senkronize olur!
  Future<void> _saveData() async {
    await UserDataService.saveModuleData('bamboo_coins', _coins);
    await UserDataService.saveModuleData('bamboo_water_count', _waterCount);
    await UserDataService.saveModuleData('bamboo_seeds_count', _seedCount);
    await UserDataService.saveModuleData('bamboo_name_tags_count', _nameTagCount);
  }

  void _buyItem(String itemName, int cost, VoidCallback onSuccess) {
    if (_coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeterli Coinin yok! Ders çalışarak coin kazanmalısın. 🪙'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _coins -= cost;
      onSuccess();
    });
    BambooEconomy.coinNotifier.value = _coins;
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$itemName başarıyla satın alındı! 🎉'),
        backgroundColor: Colors.greenAccent,
      ),
    );
  }

  void _buyAndSelectColor(Map<String, dynamic> skin) async {
    String key = skin['key'];
    int cost = skin['cost'];

    if (_unlockedColors.contains(key)) {
      await BambooEconomy.setActiveColor(key);
      setState(() {
        _activeColor = key;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bambu rengi aktif edildi! ✨'), backgroundColor: Colors.cyanAccent),
      );
      return;
    }

    if (_coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu renk skini için yeterli Coinin yok! 🪙'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _coins -= cost;
      _unlockedColors.add(key);
      _activeColor = key;
    });
    BambooEconomy.coinNotifier.value = _coins;

    await BambooEconomy.setActiveColor(key);
    await BambooEconomy.unlockColor(key);
    await _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${skin['name']} skini satın alındı ve uygulandı! 🔥'), backgroundColor: Colors.greenAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Bambu Market & Envanter'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amberAccent, width: 1),
              ),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    '$_coins',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              'Bambu Renk Skinleri (Neon)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coinlerini harcayarak bambuna özel neon renkler aç ve tarzını yansıt!',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ..._colorSkins.map((skin) {
              bool isUnlocked = _unlockedColors.contains(skin['key']);
              bool isActive = _activeColor == skin['key'];
              Color skinColor = skin['color'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? skinColor : Colors.white12,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: skinColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: skinColor, width: 2),
                      ),
                      child: Center(
                        child: Icon(Icons.eco, color: skinColor, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(skin['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            isActive ? 'Aktif Kullanılıyor' : (isUnlocked ? 'Kilidi Açık' : '${skin['cost']} 🪙'),
                            style: TextStyle(color: isActive ? skinColor : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? Colors.white24 : (isUnlocked ? skinColor : Colors.amberAccent),
                        foregroundColor: isActive ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _buyAndSelectColor(skin),
                      child: Text(
                        isActive ? 'Aktif' : (isUnlocked ? 'Seç' : '${skin['cost']} 🪙'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            const Text(
              'Envanter & Destek Ürünleri',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Su Damlası
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('💧', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Su Damlası', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        const Text('Bambuyu sulayarak boy atmasını sağlar.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('Depodaki: $_waterCount', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _buyItem('Su Damlası', 10, () => _waterCount++),
                    child: const Text('10 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            // Bambu Tohumu
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('🌰', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bambu Tohumu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        const Text('Ormana yeni bir bambu ekmek için tohum.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('Depodaki: $_seedCount', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _buyItem('Bambu Tohumu', 30, () => _seedCount++),
                    child: const Text('30 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            // İsim Etiketi (Name Tag)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('🏷️', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('İsim Etiketi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        const Text('Seçili bambunun adını değiştirmek için kullanım hakkı verir.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('Depodaki: $_nameTagCount', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _buyItem('İsim Etiketi', 50, () => _nameTagCount++),
                    child: const Text('50 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}