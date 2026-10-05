import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_data_service.dart';

// =====================================================================
// VERİ MODELİ
// =====================================================================

class MathFunctionItem {
  String id;
  int colorValue;
  bool isVisible;

  String _expression;
  _Node? _cachedNode;
  String? _cachedError;

  MathFunctionItem({
    required this.id,
    required this._expression,
    required this.colorValue,
    this.isVisible = true,
  });

  String get expression => _expression;

  /// İfade her değiştiğinde önbelleğe alınmış (parse edilmiş) ağacı geçersiz kılar.
  set expression(String value) {
    if (_expression == value) return;
    _expression = value;
    _cachedNode = null;
    _cachedError = null;
  }

  /// İfadeyi (varsa) önbellekten kullanarak parse eder. Grafik her çizildiğinde
  /// string'i baştan işlemek yerine bir kere parse edip ağacı saklarız; bu da
  /// panlama/zoom sırasında ciddi performans kazancı sağlar.
  _Node? get compiledNode {
    if (_cachedNode != null || _cachedError != null) return _cachedNode;
    try {
      _cachedNode = MathParser(_expression).parseFull();
    } catch (e) {
      _cachedError = e.toString();
      _cachedNode = null;
    }
    return _cachedNode;
  }

  String? get parseError {
    // compiledNode getter'ını tetikleyerek hata varsa doldurulmasını sağla.
    compiledNode;
    return _cachedError;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'expr': expression,
        'color': colorValue,
        'visible': isVisible,
      };

  factory MathFunctionItem.fromJson(Map<String, dynamic> json) {
    return MathFunctionItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      expression: json['expr'] ?? 'x',
      colorValue: json['color'] ?? Colors.amber.value,
      isVisible: json['visible'] ?? true,
    );
  }
}

class GrafikDataManager {
  static List<MathFunctionItem> functions = [];

  static Future<String> _getUserKey() async {
    try {
      final allData = await UserDataService.fetchAllData();
      String userEmail = allData['current_user_email'] ?? 'default_user';
      return 'grafik_functions_$userEmail';
    } catch (e) {
      return 'grafik_functions_default';
    }
  }

  static Future<void> loadData() async {
    try {
      final allData = await UserDataService.fetchAllData();
      final String key = await _getUserKey();
      final String? dataStr = allData[key];
      if (dataStr != null && dataStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(dataStr);
        functions = decoded.map((f) => MathFunctionItem.fromJson(f)).toList();
      } else {
        functions = [];
      }
    } catch (e) {
      functions = [];
    }
  }

  static Future<void> saveData() async {
    final String encoded =
        jsonEncode(functions.map((f) => f.toJson()).toList());
    final String key = await _getUserKey();
    await UserDataService.saveModuleData(key, encoded);
  }
}

// =====================================================================
// MATEMATİK İFADE MOTORU (Tokenizer + Recursive-Descent Parser)
//
// Eski sürüm string üzerinde regex/replace ile çalışıyordu; bu yöntem:
//  - "-x" gibi basit ifadelerde 0 döndürüyordu (parantezli x'i sayıya
//    çeviremiyordu),
//  - "(x+1)^2" gibi parantezli üslü ifadeleri desteklemiyordu,
//  - "ln(" tuşuna hiç yanıt vermiyordu,
//  - her pikselde (grafik başına ~400+ kez, her karede) string'i baştan
//    parse ettiği için pan/zoom sırasında performans sorununa yol
//    açıyordu.
//
// Yeni motor ifadeyi BİR KEZ bir ağaca (AST) çevirir ve o ağaç her x
// değeri için sadece sayısal olarak yeniden hesaplanır. Ayrıca geçersiz
// ifadeler için kullanıcıya gösterilebilecek anlamlı bir hata üretir.
// =====================================================================

abstract class _Node {
  double eval(double x);
}

class _NumNode extends _Node {
  final double value;
  _NumNode(this.value);
  @override
  double eval(double x) => value;
}

class _VarNode extends _Node {
  @override
  double eval(double x) => x;
}

class _UnaryMinusNode extends _Node {
  final _Node child;
  _UnaryMinusNode(this.child);
  @override
  double eval(double x) => -child.eval(x);
}

class _BinaryNode extends _Node {
  final String op;
  final _Node left;
  final _Node right;
  _BinaryNode(this.op, this.left, this.right);

  @override
  double eval(double x) {
    final double l = left.eval(x);
    final double r = right.eval(x);
    switch (op) {
      case '+':
        return l + r;
      case '-':
        return l - r;
      case '*':
        return l * r;
      case '/':
        return l / r; // 0'a bölme -> inf/NaN, çizim sırasında atlanır.
      case '^':
        return math.pow(l, r).toDouble();
      default:
        throw FormatException('Bilinmeyen operatör: $op');
    }
  }
}

class _FuncNode extends _Node {
  final String name;
  final _Node arg;
  _FuncNode(this.name, this.arg);

  @override
  double eval(double x) {
    final double v = arg.eval(x);
    switch (name) {
      case 'sin':
        return math.sin(v);
      case 'cos':
        return math.cos(v);
      case 'tan':
        return math.tan(v);
      case 'asin':
        return math.asin(v);
      case 'acos':
        return math.acos(v);
      case 'atan':
        return math.atan(v);
      case 'sqrt':
        return math.sqrt(v);
      case 'abs':
        return v.abs();
      case 'ln':
        return math.log(v); // doğal logaritma
      case 'log':
        return math.log(v) / math.ln10; // 10 tabanlı logaritma
      default:
        throw FormatException('Bilinmeyen fonksiyon: $name');
    }
  }
}

class _Token {
  final String type; // num, ident, op, lparen, rparen
  final String text;
  _Token(this.type, this.text);
}

const Set<String> _kKnownFunctions = {
  'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'abs', 'ln', 'log',
};
const Set<String> _kConstants = {'pi', 'e'};

List<_Token> _tokenize(String input) {
  final String s = input.replaceAll(' ', '').toLowerCase();
  final List<_Token> raw = [];
  int i = 0;
  while (i < s.length) {
    final String c = s[i];
    if (c == '(') {
      raw.add(_Token('lparen', c));
      i++;
    } else if (c == ')') {
      raw.add(_Token('rparen', c));
      i++;
    } else if ('+-*/^'.contains(c)) {
      raw.add(_Token('op', c));
      i++;
    } else if (RegExp(r'[0-9.]').hasMatch(c)) {
      int j = i;
      while (j < s.length && RegExp(r'[0-9.]').hasMatch(s[j])) {
        j++;
      }
      raw.add(_Token('num', s.substring(i, j)));
      i = j;
    } else if (RegExp(r'[a-z]').hasMatch(c)) {
      int j = i;
      while (j < s.length && RegExp(r'[a-z]').hasMatch(s[j])) {
        j++;
      }
      String word = s.substring(i, j);
      // Bilinen fonksiyon/sabit isimlerini önceliklendir; aksi halde
      // her harfi ayrı bir "x" değişkeni gibi ele alacağız (implicit
      // çarpım desteği aşağıda uygulanıyor). Tek desteklenen değişken
      // 'x' olduğundan, tanınmayan kelimeleri harf harf değişken/sabit
      // parçalarına ayırıyoruz (örn. "xx" -> x*x gibi anlamlı olsun diye
      // sadece 'x' harfini değişken kabul ediyoruz, diğerlerini hataya
      // düşürüyoruz).
      if (_kKnownFunctions.contains(word) || _kConstants.contains(word)) {
        raw.add(_Token('ident', word));
        i = j;
      } else {
        // kelimeyi tek tek harflere böl (x, pi, e alt-kombinasyonlarını
        // yakalamaya çalış), desteklenmeyen harfte hata fırlat.
        int k = i;
        while (k < j) {
          if (s.startsWith('pi', k)) {
            raw.add(_Token('ident', 'pi'));
            k += 2;
          } else if (s[k] == 'e') {
            raw.add(_Token('ident', 'e'));
            k += 1;
          } else if (s[k] == 'x') {
            raw.add(_Token('ident', 'x'));
            k += 1;
          } else {
            throw FormatException('Tanınmayan ifade: "${s[k]}"');
          }
        }
        i = j;
      }
    } else {
      throw FormatException('Tanınmayan karakter: "$c"');
    }
  }

  // --- Örtük çarpım (implicit multiplication) ekleme ---
  // Örn: "2x" -> 2*x, "2(x+1)" -> 2*(x+1), "x(x+1)" -> x*(x+1),
  // "(x+1)(x-1)" -> (x+1)*(x-1)
  final List<_Token> withMul = [];
  for (int idx = 0; idx < raw.length; idx++) {
    final _Token cur = raw[idx];
    if (withMul.isNotEmpty) {
      final _Token prev = withMul.last;
      final bool prevEndsValue = prev.type == 'num' ||
          prev.type == 'rparen' ||
          (prev.type == 'ident' && !_kKnownFunctions.contains(prev.text));
      final bool curStartsValue = cur.type == 'num' ||
          cur.type == 'lparen' ||
          cur.type == 'ident';
      if (prevEndsValue && curStartsValue) {
        withMul.add(_Token('op', '*'));
      }
    }
    withMul.add(cur);
  }
  return withMul;
}

/// Basit recursive-descent parser.
/// Dilbilgisi:
///   expression := term (('+'|'-') term)*
///   term       := unary (('*'|'/') unary)*
///   unary      := '-' unary | power
///   power      := primary ('^' unary)?      (sağdan-birleşimli)
///   primary    := sayı | sabit | 'x' | fonksiyon '(' expression ')'
///                 | '(' expression ')'
class MathParser {
  final List<_Token> _tokens;
  int _pos = 0;

  MathParser(String expr) : _tokens = _tokenize(expr);

  _Token? get _current => _pos < _tokens.length ? _tokens[_pos] : null;

  _Node parseFull() {
    if (_tokens.isEmpty) {
      throw const FormatException('Boş ifade');
    }
    final _Node node = _parseExpression();
    if (_pos != _tokens.length) {
      throw FormatException('Beklenmeyen simge: "${_current?.text}"');
    }
    return node;
  }

  _Node _parseExpression() {
    _Node node = _parseTerm();
    while (_current != null &&
        _current!.type == 'op' &&
        (_current!.text == '+' || _current!.text == '-')) {
      final String op = _current!.text;
      _pos++;
      final _Node right = _parseTerm();
      node = _BinaryNode(op, node, right);
    }
    return node;
  }

  _Node _parseTerm() {
    _Node node = _parseUnary();
    while (_current != null &&
        _current!.type == 'op' &&
        (_current!.text == '*' || _current!.text == '/')) {
      final String op = _current!.text;
      _pos++;
      final _Node right = _parseUnary();
      node = _BinaryNode(op, node, right);
    }
    return node;
  }

  _Node _parseUnary() {
    if (_current != null && _current!.type == 'op' && _current!.text == '-') {
      _pos++;
      return _UnaryMinusNode(_parseUnary());
    }
    if (_current != null && _current!.type == 'op' && _current!.text == '+') {
      _pos++;
      return _parseUnary();
    }
    return _parsePower();
  }

  _Node _parsePower() {
    final _Node base = _parsePrimary();
    if (_current != null && _current!.type == 'op' && _current!.text == '^') {
      _pos++;
      final _Node exponent = _parseUnary(); // sağdan birleşimli
      return _BinaryNode('^', base, exponent);
    }
    return base;
  }

  _Node _parsePrimary() {
    final _Token? tok = _current;
    if (tok == null) {
      throw const FormatException('İfade eksik');
    }

    if (tok.type == 'num') {
      _pos++;
      final double? v = double.tryParse(tok.text);
      if (v == null) throw FormatException('Geçersiz sayı: "${tok.text}"');
      return _NumNode(v);
    }

    if (tok.type == 'lparen') {
      _pos++;
      final _Node inner = _parseExpression();
      _expect('rparen', ')');
      return inner;
    }

    if (tok.type == 'ident') {
      if (tok.text == 'x') {
        _pos++;
        return _VarNode();
      }
      if (tok.text == 'pi') {
        _pos++;
        return _NumNode(math.pi);
      }
      if (tok.text == 'e') {
        _pos++;
        return _NumNode(math.e);
      }
      if (_kKnownFunctions.contains(tok.text)) {
        final String fname = tok.text;
        _pos++;
        _expect('lparen', '(');
        final _Node arg = _parseExpression();
        _expect('rparen', ')');
        return _FuncNode(fname, arg);
      }
    }

    throw FormatException('Beklenmeyen simge: "${tok.text}"');
  }

  void _expect(String type, String display) {
    if (_current == null || _current!.type != type) {
      throw FormatException('"$display" bekleniyordu');
    }
    _pos++;
  }
}

/// Verilen ifadeyi x=1.0 üzerinden test ederek geçerli olup olmadığını
/// döndürür. Geçerliyse null, değilse kullanıcıya gösterilecek kısa bir
/// hata metni döner.
String? validateExpression(String expr) {
  if (expr.trim().isEmpty) return 'İfade boş olamaz';
  try {
    final _Node node = MathParser(expr).parseFull();
    // Bariz bir sayısal hata olup olmadığını görmek için birkaç noktada dene.
    node.eval(1.0);
    node.eval(0.5);
    return null;
  } catch (e) {
    final msg = e is FormatException ? e.message : e.toString();
    return msg;
  }
}

/// GraphPainter tarafından kullanılan public API — imzası eskisiyle aynı.
double? evaluateExpression(String expr, double x) {
  try {
    final _Node node = MathParser(expr).parseFull();
    return node.eval(x);
  } catch (e) {
    return null;
  }
}

// =====================================================================
// ANA EKRAN
// =====================================================================

class GrafikScreen extends StatefulWidget {
  const GrafikScreen({super.key});

  @override
  State<GrafikScreen> createState() => _GrafikScreenState();
}

class _GrafikScreenState extends State<GrafikScreen> {
  bool _isLoading = true;

  Offset _panOffset = Offset.zero;
  double _zoomScale = 40.0;

  // Pinch/pan hareketinin BAŞLANGICINDAKİ değerlerini tutar. Flutter'ın
  // ScaleUpdateDetails.scale değeri jest başlangıcından bu yana KÜMÜLATİF
  // bir orandır; eski kod bunu her karede _zoomScale'e çarparak zoom'un
  // katlanarak (üstel) ve kontrolsüz şekilde artmasına yol açıyordu.
  // Ayrıca hiçbir zaman iki parmağın odak noktasına (focal point) göre
  // ölçeklenmiyordu; bu yüzden pinch sırasında grafik "kayıyor" gibi
  // hissettiriyordu. Aşağıdaki yaklaşım her iki sorunu da çözer.
  Offset? _gestureStartFocalPoint;
  Offset? _gestureStartPanOffset;
  double _gestureStartZoom = 40.0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await GrafikDataManager.loadData();
    setState(() => _isLoading = false);
  }

  void _resetView() {
    setState(() {
      _panOffset = Offset.zero;
      _zoomScale = 40.0;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartFocalPoint = details.focalPoint;
    _gestureStartPanOffset = _panOffset;
    _gestureStartZoom = _zoomScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_gestureStartFocalPoint == null || _gestureStartPanOffset == null) {
      return;
    }
    final Size size = MediaQuery.of(context).size;
    final double newZoom =
        (_gestureStartZoom * details.scale).clamp(1.0, 5000.0);

    // Jest başlangıcındaki odak noktasının altındaki matematiksel noktayı
    // ekranda sabit tutacak şekilde yeni pan ofsetini hesapla.
    final Offset centerAtStart = Offset(
      size.width / 2 + _gestureStartPanOffset!.dx,
      size.height / 2 + _gestureStartPanOffset!.dy,
    );
    final Offset focalOffsetFromCenter =
        _gestureStartFocalPoint! - centerAtStart;
    final double scaleRatio = newZoom / _gestureStartZoom;
    final Offset newCenter =
        details.focalPoint - focalOffsetFromCenter * scaleRatio;

    setState(() {
      _zoomScale = newZoom;
      _panOffset = newCenter - Offset(size.width / 2, size.height / 2);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _gestureStartFocalPoint = null;
    _gestureStartPanOffset = null;
  }

  void _zoomBy(double factor) {
    setState(() {
      _zoomScale = (_zoomScale * factor).clamp(1.0, 5000.0);
    });
  }

  void _clearAllFunctions() {
    if (GrafikDataManager.functions.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Tümünü Temizle', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Eklenen tüm fonksiyonlar silinecek. Emin misin?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                GrafikDataManager.functions.clear();
                GrafikDataManager.saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('Temizle',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddEditFunctionDialog({MathFunctionItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return _AddEditFunctionSheet(
          item: item,
          onSaved: (expr, color) {
            setState(() {
              if (item == null) {
                GrafikDataManager.functions.add(MathFunctionItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  expression: expr,
                  colorValue: color,
                ));
              } else {
                item.expression = expr;
                item.colorValue = color;
              }
              GrafikDataManager.saveData();
            });
          },
        );
      },
    );
  }

  void _openFunctionList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _FunctionListBottomSheet(
        onUpdate: () => setState(() {}),
        onEdit: (item) {
          Navigator.pop(context); // liste sheet'ini kapat
          _showAddEditFunctionDialog(item: item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    final bool hasFunctions = GrafikDataManager.functions.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('GrafikX - Fonksiyon Çizici'),
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.amber),
            onPressed: _resetView,
            tooltip: 'Başa Dön (Orijin)',
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep,
                color: hasFunctions ? Colors.redAccent : Colors.white24),
            onPressed: hasFunctions ? _clearAllFunctions : null,
            tooltip: 'Tümünü Temizle',
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, color: Colors.cyanAccent),
            onPressed: _openFunctionList,
            tooltip: 'Fonksiyonları Yönet',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: GraphPainter(
                functions: GrafikDataManager.functions,
                panOffset: _panOffset,
                zoomScale: _zoomScale,
              ),
            ),
          ),
          if (!hasFunctions)
            IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.functions, color: Colors.white38, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Başlamak için sol alttaki\n"Fonksiyon Ekle" butonuna dokun',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // SAĞ ALT: Zoom Butonları
          Positioned(
            right: 20,
            bottom: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  mini: true,
                  backgroundColor: const Color(0xFF1F1F1F),
                  foregroundColor: Colors.white,
                  onPressed: () => _zoomBy(1.15),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  mini: true,
                  backgroundColor: const Color(0xFF1F1F1F),
                  foregroundColor: Colors.white,
                  onPressed: () => _zoomBy(1 / 1.15),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          // SOL ALT: Fonksiyon Ekle Butonu
          Positioned(
            left: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: () => _showAddEditFunctionDialog(),
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Fonksiyon Ekle', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// FONKSİYON EKLE / DÜZENLE SHEET
// (Artık canlı doğrulama yapıyor: geçersiz ifadede kaydet butonu kapalı
// ve kullanıcıya neden geçersiz olduğu gösteriliyor.)
// =====================================================================

class _AddEditFunctionSheet extends StatefulWidget {
  final MathFunctionItem? item;
  final void Function(String expression, int colorValue) onSaved;

  const _AddEditFunctionSheet({required this.item, required this.onSaved});

  @override
  State<_AddEditFunctionSheet> createState() => _AddEditFunctionSheetState();
}

class _AddEditFunctionSheetState extends State<_AddEditFunctionSheet> {
  late final TextEditingController _controller;
  late int _selectedColor;
  String? _errorText;

  static const List<Color> _availableColors = [
    Colors.amber,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.lightBlueAccent,
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item?.expression ?? '');
    _selectedColor = widget.item?.colorValue ?? Colors.amber.value;
    _validate(_controller.text);
    _controller.addListener(() => _validate(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String text) {
    final String? err = text.trim().isEmpty ? null : validateExpression(text);
    if (err != _errorText) {
      setState(() => _errorText = err);
    }
  }

  bool get _canSave => _controller.text.trim().isNotEmpty && _errorText == null;

  void _save() {
    if (!_canSave) return;
    widget.onSaved(_controller.text.trim(), _selectedColor);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.item != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Fonksiyonu Düzenle' : 'Yeni Fonksiyon Ekle',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'f(x) ifadesi yazın (örn: x^2, sin(x))',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF121212),
                errorText: _errorText,
                errorMaxLines: 2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _errorText != null ? Colors.redAccent : Colors.transparent,
                      width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Çizgi Rengi:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _availableColors.map((color) {
                bool isSelected = _selectedColor == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedColor = color.toARGB32());
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _MathKeyboard(controller: _controller),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSave ? Colors.deepPurple : Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _canSave ? _save : null,
                child: Text(
                  'Kaydet ve Çiz',
                  style: TextStyle(
                    color: _canSave ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// MATEMATİK KLAVYESİ WIDGET'I
// (Artık yalnızca gerçekten desteklenen anahtarları içeriyor; eskiden
// "ln(", "sin⁻¹", "d/dx", "∫" gibi tuşlar arayüzde duruyordu ama
// evaluator bunları hiç tanımıyordu ve sessizce başarısız oluyordu.)
// =====================================================================

class _MathKeyboard extends StatefulWidget {
  final TextEditingController controller;
  const _MathKeyboard({required this.controller});

  @override
  State<_MathKeyboard> createState() => _MathKeyboardState();
}

class _MathKeyboardState extends State<_MathKeyboard> {
  int _selectedTab = 0;

  void _insertText(String text) {
    final textVal = widget.controller.text;
    final selection = widget.controller.selection;
    if (selection.isValid) {
      final newText = textVal.replaceRange(selection.start, selection.end, text);
      widget.controller.text = newText;
      widget.controller.selection =
          TextSelection.collapsed(offset: selection.start + text.length);
    } else {
      widget.controller.text = textVal + text;
      widget.controller.selection =
          TextSelection.collapsed(offset: widget.controller.text.length);
    }
  }

  void _backspace() {
    final textVal = widget.controller.text;
    final selection = widget.controller.selection;
    if (selection.isValid && selection.start > 0) {
      final newText = textVal.replaceRange(selection.start - 1, selection.end, '');
      widget.controller.text = newText;
      widget.controller.selection = TextSelection.collapsed(offset: selection.start - 1);
    } else if (!selection.isValid && textVal.isNotEmpty) {
      widget.controller.text = textVal.substring(0, textVal.length - 1);
      widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
    }
  }

  void _clearField() {
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabButton('123', 0),
              _buildTabButton('f(x)', 1),
              _buildTabButton('sabit', 2),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 4),
          _buildKeyboardGrid(),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(title,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildKeyboardGrid() {
    // Her tuş (görünen_metin, eklenecek_metin) çifti olarak tanımlanır;
    // görünen metin daha okunaklı olabilir (örn. "x²") ama eklenen metin
    // her zaman evaluator'ın anladığı sözdizimidir (örn. "^2").
    List<List<String>> keys;
    if (_selectedTab == 0) {
      keys = [
        ['7', '7'], ['8', '8'], ['9', '9'], ['/', '/'], ['⌫', '⌫'],
        ['4', '4'], ['5', '5'], ['6', '6'], ['*', '*'], ['TEMİZLE', 'TEMİZLE'],
        ['1', '1'], ['2', '2'], ['3', '3'], ['-', '-'], ['(', '('],
        ['0', '0'], ['.', '.'], ['x', 'x'], ['+', '+'], [')', ')'],
      ];
    } else if (_selectedTab == 1) {
      keys = [
        ['sin', 'sin('], ['cos', 'cos('], ['tan', 'tan('], ['x²', '^2'], ['⌫', '⌫'],
        ['sin⁻¹', 'asin('], ['cos⁻¹', 'acos('], ['tan⁻¹', 'atan('], ['x³', '^3'], ['TEMİZLE', 'TEMİZLE'],
        ['√', 'sqrt('], ['|x|', 'abs('], ['ln', 'ln('], ['log', 'log('], ['^', '^'],
      ];
    } else {
      keys = [
        ['π', 'pi'], ['e', 'e'], ['x', 'x'], ['(', '('], [')', ')'],
      ];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.5,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final String display = keys[index][0];
        final String insertValue = keys[index][1];
        final bool isDel = display == '⌫';
        final bool isClear = display == 'TEMİZLE';

        return Material(
          color: isDel || isClear ? const Color(0xFF2C2C2C) : const Color(0xFF222222),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              if (isDel) {
                _backspace();
              } else if (isClear) {
                _clearField();
              } else {
                _insertText(insertValue);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              alignment: Alignment.center,
              child: Text(
                display,
                style: TextStyle(
                  color: isDel || isClear ? Colors.redAccent : Colors.white,
                  fontSize: isClear ? 10 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// FONKSİYON LİSTESİ BOTTOM SHEET
// (Artık her satıra dokununca düzenleme ekranı açılıyor; eskiden
// eklenen bir fonksiyonun ifadesini değiştirmenin tek yolu silip yeniden
// eklemekti.)
// =====================================================================

class _FunctionListBottomSheet extends StatefulWidget {
  final VoidCallback onUpdate;
  final void Function(MathFunctionItem item) onEdit;
  const _FunctionListBottomSheet({required this.onUpdate, required this.onEdit});

  @override
  State<_FunctionListBottomSheet> createState() => _FunctionListBottomSheetState();
}

class _FunctionListBottomSheetState extends State<_FunctionListBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ekli Fonksiyonlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Expanded(
              child: GrafikDataManager.functions.isEmpty
                  ? const Center(
                      child: Text('Henüz fonksiyon eklenmedi.',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.builder(
                      itemCount: GrafikDataManager.functions.length,
                      itemBuilder: (context, index) {
                        final item = GrafikDataManager.functions[index];
                        final bool hasError = item.parseError != null;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasError
                                  ? Colors.redAccent.withValues(alpha: 0.6)
                                  : Color(item.colorValue).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => widget.onEdit(item),
                            leading: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Color(item.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text('f(x) = ${item.expression}',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: hasError
                                ? const Text('Geçersiz ifade — düzenlemek için dokunun',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 11))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: item.isVisible,
                                  activeThumbColor: Colors.amber,
                                  onChanged: (val) {
                                    setState(() {
                                      item.isVisible = val;
                                      GrafikDataManager.saveData();
                                      widget.onUpdate();
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() {
                                      GrafikDataManager.functions.removeAt(index);
                                      GrafikDataManager.saveData();
                                      widget.onUpdate();
                                    });
                                  },
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white24),
                              ],
                            ),
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

// =====================================================================
// GRAFİK ÇİZİM MOTORU
// =====================================================================

class GraphPainter extends CustomPainter {
  final List<MathFunctionItem> functions;
  final Offset panOffset;
  final double zoomScale;

  GraphPainter({
    required this.functions,
    required this.panOffset,
    required this.zoomScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    final Paint axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5;

    final Offset center = Offset(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);

    double step = zoomScale;
    if (step < 20) {
      step *= 5;
    } else if (step > 100) {
      step /= 2;
    }

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Dikey Gridler ve X Ekseni Sayıları
    double startX = center.dx % step;
    for (double x = startX; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);

      double mathVal = (x - center.dx) / zoomScale;
      if (mathVal.abs() > 1e-5) {
        String labelText = (mathVal - mathVal.round()).abs() < 1e-4
            ? mathVal.round().toString()
            : mathVal.toStringAsFixed(1);

        textPainter.text = TextSpan(
          text: labelText,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        );
        textPainter.layout();
        double textY = center.dy + 4;
        if (textY < 10) textY = 10;
        if (textY > size.height - 20) textY = size.height - 20;
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, textY));
      }
    }

    // Yatay Gridler ve Y Ekseni Sayıları
    double startY = center.dy % step;
    for (double y = startY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      double mathVal = (center.dy - y) / zoomScale;
      if (mathVal.abs() > 1e-5) {
        String labelText = (mathVal - mathVal.round()).abs() < 1e-4
            ? mathVal.round().toString()
            : mathVal.toStringAsFixed(1);

        textPainter.text = TextSpan(
          text: labelText,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        );
        textPainter.layout();
        double textX = center.dx + 6;
        if (textX < 5) textX = 5;
        if (textX > size.width - 30) textX = size.width - 30;
        textPainter.paint(canvas, Offset(textX, y - textPainter.height / 2));
      }
    }

    // Ana Eksenler (X ve Y)
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);

    // Orijin (0,0) etiketi
    textPainter.text = const TextSpan(
      text: '0',
      style: TextStyle(color: Colors.white54, fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx + 4, center.dy + 4));

    // Fonksiyon Eğrileri
    // Not: Her fonksiyonun ifadesi artık PİKSEL BAŞINA değil, kare başına
    // (fonksiyon başına) tek seferde parse ediliyor (bkz. MathFunctionItem
    // .compiledNode önbelleği). Bu, pan/zoom sırasındaki gecikmeyi ortadan
    // kaldırır.
    for (var func in functions) {
      if (!func.isVisible) continue;
      final _Node? node = func.compiledNode;
      if (node == null) continue; // geçersiz ifade, sessizce atla (liste ekranında uyarı gösteriliyor)

      final Paint curvePaint = Paint()
        ..color = Color(func.colorValue)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      Path path = Path();
      bool isFirstPoint = true;
      double? lastPy;

      for (double px = 0; px <= size.width; px += 2) {
        double mathX = (px - center.dx) / zoomScale;
        double mathY;
        try {
          mathY = node.eval(mathX);
        } catch (e) {
          mathY = double.nan;
        }

        if (!mathY.isNaN && !mathY.isInfinite) {
          double py = center.dy - (mathY * zoomScale);

          // Dikey asimptotlarda (ör. tan(x)) ekranı baştan sona kaplayan
          // dikey bir çizgi çizilmesini önlemek için ardışık noktalar
          // arasında çok büyük bir sıçrama varsa çizgiyi kes.
          final bool hugeJump = lastPy != null && (py - lastPy).abs() > size.height * 3;

          if (isFirstPoint || hugeJump) {
            path.moveTo(px, py);
            isFirstPoint = false;
          } else {
            path.lineTo(px, py);
          }
          lastPy = py;
        } else {
          isFirstPoint = true;
          lastPy = null;
        }
      }
      canvas.drawPath(path, curvePaint);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    // Not: `functions` aynı statik listeye referans olduğundan (liste içerik
    // olarak değişse de referansı aynı kalır), burada içerik karşılaştırması
    // güvenilir değildir — bu yüzden her zaman true dönüyoruz. Asıl
    // performans kazancı artık piksel başına string parse etmek yerine
    // ifadeleri kare başına bir kez (ve önbellekli olarak) parse etmekten
    // geliyor, dolayısıyla her karede repaint yapmanın maliyeti düşük.
    return true;
  }
}