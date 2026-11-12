// Meus Protocolos — contador de protocolos e UPs
// Leitura de print feita no próprio celular (Google ML Kit, funciona sem internet).

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

// ───────────────────────── cores ─────────────────────────
const kBg = Color(0xFF0B1220);
const kCard = Color(0xFF131C2E);
const kCard2 = Color(0xFF1A2540);
const kLine = Color(0xFF243150);
const kText = Color(0xFFE8EEFC);
const kMuted = Color(0xFF8A97B2);
const kDim = Color(0xFF5D6A86);
const kAcc1 = Color(0xFF10B981);
const kAcc2 = Color(0xFF06B6D4);
const kDark = Color(0xFF04151A);
const kWarn = Color(0xFFFBBF24);

Color withA(int rgb, int a) => Color((a << 24) | (rgb & 0xFFFFFF));

// ───────────────────────── tabela de UPs ─────────────────────────
class Cat {
  final String id, name, emoji;
  final int rgb;
  const Cat(this.id, this.name, this.emoji, this.rgb);
  Color get color => withA(rgb, 0xFF);
  Color get bg => withA(rgb, 0x26);
}

const cats = <Cat>[
  Cat('inst', 'Instalação', '🔌', 0x22C55E),
  Cat('man', 'Manutenção', '🛠️', 0xF59E0B),
  Cat('mud', 'Mudança', '🏠', 0x3B82F6),
  Cat('mig', 'Migração', '🔄', 0xA855F7),
  Cat('pto', 'Ponto adicional', '➕', 0x06B6D4),
  Cat('ret', 'Retirada', '📦', 0xEF4444),
];
final catById = {for (final c in cats) c.id: c};

class SType {
  final String id, name, cat;
  final double up;
  const SType(this.id, this.name, this.up, this.cat);
}

const types = <SType>[
  SType('atd', 'Atendimento Técnico', 0.67, 'man'),
  SType('atdc', 'Atendimento Técnico Corporativo', 0.67, 'man'),
  SType('radmc', 'Rádio - Manutenção Corretiva', 0.67, 'man'),
  SType('mhtvmc', 'MHTV - Manutenção Corretiva', 0.67, 'man'),
  SType('telmc', 'Telefone - Manutenção Corretiva', 0.67, 'man'),
  SType('fibrom', 'Fibra Rompida', 4.76, 'man'),
  SType('utp', 'Rompimento Cabo UTP', 1.00, 'man'),
  SType('ftth', 'Fibra - Instalação FTTH', 1.33, 'inst'),
  SType('fttb', 'Fibra - Instalação FTTB', 1.33, 'inst'),
  SType('ftta', 'Fibra - Instalação FTTA', 1.33, 'inst'),
  SType('radinst', 'Rádio - Instalação', 1.00, 'inst'),
  SType('telinst', 'Telefone - Instalação', 0.67, 'inst'),
  SType('cam', 'Instalação de Câmera', 2.00, 'inst'),
  SType('upg', 'Upgrade Imediato', 2.00, 'inst'),
  SType('mhplay', 'MH Play', 0.67, 'inst'),
  SType('mudftth', 'Fibra - Mudança de Endereço FTTH', 1.50, 'mud'),
  SType('mudfttb', 'Fibra - Mudança de Endereço FTTB', 1.00, 'mud'),
  SType('mudftta', 'Fibra - Mudança de Endereço FTTA', 1.00, 'mud'),
  SType('mudrad', 'Rádio - Mudança de Endereço', 1.33, 'mud'),
  SType('migepon', 'Migração EPON/GPON', 0.67, 'mig'),
  SType('migfr', 'Migração Fibra/Rádio', 1.50, 'mig'),
  SType('migrf', 'Migração Rádio/Fibra', 1.50, 'mig'),
  SType('ptoinst', 'Instalação - Ponto Adicional', 1.00, 'pto'),
  SType('ptorad', 'Rádio - Ponto Adicional', 1.00, 'pto'),
  SType('ptomhtv', 'MHTV - Ponto Adicional', 1.00, 'pto'),
  SType('ptotel', 'Telefone - Ponto Adicional', 1.00, 'pto'),
  SType('retint', 'Recolhimento Integral', 4.76, 'ret'),
  SType('retpar', 'Recolhimento Parcial', 3.57, 'ret'),
];
final typeById = {for (final t in types) t.id: t};

/// Textos que aparecem no Voalle → tipos possíveis (sem acento, minúsculo).
/// Quando há mais de um tipo possível, o app pede para você escolher.
const typeAliases = <String, List<String>>{
  'atendimento tecnico corporativo': ['atdc'],
  'atendimento tecnico': ['atd'],
  'radio manutencao corretiva': ['radmc'],
  'mhtv manutencao corretiva': ['mhtvmc'],
  'telefone manutencao corretiva': ['telmc'],
  'manutencao corretiva': ['atd', 'atdc', 'radmc', 'mhtvmc', 'telmc'],
  'fibra rompida': ['fibrom'],
  'rompimento cabo utp': ['utp'],
  'instalacao ftth': ['ftth'],
  'instalacao fttb': ['fttb'],
  'instalacao ftta': ['ftta'],
  'radio instalacao': ['radinst'],
  'instalacao de radio': ['radinst'],
  'telefone instalacao': ['telinst'],
  'instalacao de telefone': ['telinst'],
  'instalacao de camera': ['cam'],
  'wifi total': ['cam'],
  'upgrade imediato': ['upg'],
  'mh play': ['mhplay'],
  'mudanca endereco ftth': ['mudftth'],
  'mudanca endereco fttb': ['mudfttb'],
  'mudanca endereco ftta': ['mudftta'],
  'mudanca de endereco ftth': ['mudftth'],
  'mudanca de endereco fttb': ['mudfttb'],
  'mudanca de endereco ftta': ['mudftta'],
  'radio mudanca endereco': ['mudrad'],
  'radio mudanca de endereco': ['mudrad'],
  'mudanca de endereco radio': ['mudrad'],
  'migracao epon gpon': ['migepon'],
  'migracao fibra radio': ['migfr'],
  'migracao radio fibra': ['migrf'],
  'instalacao ponto adicional': ['ptoinst'],
  'radio ponto adicional': ['ptorad'],
  'mhtv ponto adicional': ['ptomhtv'],
  'telefone ponto adicional': ['ptotel'],
  'ponto adicional telefone': ['ptotel'],
  'ponto adicional mhtv': ['ptomhtv'],
  'ponto adicional internet': ['ptoinst', 'ptorad'],
  'recolhimento integral': ['retint'],
  'recolhimento parcial': ['retpar'],
  'retirada': ['retint', 'retpar'],
  // nomes que aparecem no CSV do Elleven
  'atendimento corporativo': ['atdc'],
  'instalacao de cameras': ['cam'],
  'atendimento tecnico mh play streaming': ['mhplay'],
  'mh play streaming': ['mhplay'],
  'upgrade': ['upg'],
};
final List<String> _aliasKeys = typeAliases.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

// ───────────────────────── utilitários ─────────────────────────
const monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];
const monthShort = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
const weekShort = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
const weekLong = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];

String two(int n) => n.toString().padLeft(2, '0');

String num2(double v) {
  final neg = v < 0;
  final parts = v.abs().toStringAsFixed(2).split('.');
  final ip = parts[0];
  final sb = StringBuffer();
  for (var i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) sb.write('.');
    sb.write(ip[i]);
  }
  return '${neg ? '-' : ''}$sb,${parts[1]}';
}

String brl(double v) => 'R\$ ${num2(v)}';

double? parseNum(String s) {
  var t = s.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String norm(String s) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyAAAAAACEEEEIIIINOOOOOUUUUY';
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    sb.write(i >= 0 ? to[i] : ch);
  }
  return sb.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

List<String> matchType(String s) {
  final n = ' ${norm(s)} ';
  for (final k in _aliasKeys) {
    if (n.contains(' $k ')) return typeAliases[k]!;
  }
  final byLen = [...types]..sort((a, b) => b.name.length.compareTo(a.name.length));
  for (final t in byLen) {
    if (n.contains(' ${norm(t.name)} ')) return [t.id];
  }
  return [];
}

DateTime? parseDate(String s) {
  var m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})(?:[ T,;\-]+(\d{1,2}):(\d{2}))?').firstMatch(s);
  if (m != null) {
    return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!),
        int.parse(m.group(4) ?? '12'), int.parse(m.group(5) ?? '0'));
  }
  m = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?').firstMatch(s);
  if (m != null) {
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!),
        int.parse(m.group(4) ?? '12'), int.parse(m.group(5) ?? '0'));
  }
  return null;
}

Widget catIcon(Cat c, double size) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(size / 3)),
      child: Text(c.emoji, style: TextStyle(fontSize: size * 0.45)),
    );

// ───────────────────────── dados ─────────────────────────
class Proto {
  final String p;
  final String t;
  final double up;
  final int ts;
  Proto(this.p, this.t, this.up, this.ts);

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(ts);
  Map<String, dynamic> toJson() => {'p': p, 't': t, 'up': up, 'ts': ts};
  factory Proto.fromJson(Map<String, dynamic> j) =>
      Proto('${j['p']}', '${j['t']}', (j['up'] as num).toDouble(), (j['ts'] as num).toInt());
}

// ───────────────────────── leitura do print ─────────────────────────
class ShotResult {
  String? proto;
  List<String> typeIds = [];
  String rawType = '';
  DateTime? date;
}

Future<ShotResult> readShot(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final out = await recognizer.processImage(InputImage.fromFilePath(path));
    final lines = <TextLine>[];
    for (final b in out.blocks) {
      lines.addAll(b.lines);
    }
    // ordem de leitura: de cima para baixo, da esquerda para a direita
    lines.sort((a, b) {
      final dy = a.boundingBox.top - b.boundingBox.top;
      if (dy.abs() > 12) return dy < 0 ? -1 : 1;
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });
    return parseVoalle(lines.map((l) => l.text).join('\n'));
  } finally {
    await recognizer.close();
  }
}

ShotResult parseVoalle(String text) {
  final r = ShotResult();
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  // 1) número do protocolo
  final m1 = RegExp(r'Protocolo\s*n\s*[°ºo.]?\s*(\d{5,12})', caseSensitive: false).firstMatch(text);
  if (m1 != null) r.proto = m1.group(1);
  if (r.proto == null) {
    for (var i = 0; i < lines.length - 1; i++) {
      if (norm(lines[i]) == 'protocolo') {
        final d = RegExp(r'^\d{5,12}$').firstMatch(lines[i + 1].replaceAll(' ', ''));
        if (d != null) {
          r.proto = d.group(0);
          break;
        }
      }
    }
  }
  if (r.proto == null) {
    final all = RegExp(r'(?<![\d/:])\d{6,12}(?![\d/:])').allMatches(text).map((m) => m.group(0)!).toList();
    if (all.isNotEmpty) {
      all.sort((a, b) => b.length.compareTo(a.length));
      r.proto = all.first;
    }
  }

  // 2) tipo de solicitação
  final cands = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (norm(lines[i]).startsWith('tipo de solicita') && i + 1 < lines.length) cands.add(lines[i + 1]);
  }
  for (final l in lines) {
    final m = RegExp(r'[O0]\s*&\s*M\s*[-–—]\s*(.+)').firstMatch(l);
    if (m != null && !norm(l).contains('protocolo')) cands.add(m.group(1)!);
  }
  for (final c in cands) {
    final ids = matchType(c);
    if (ids.isNotEmpty) {
      r.typeIds = ids;
      r.rawType = c;
      break;
    }
  }
  if (r.typeIds.isEmpty && cands.isNotEmpty) r.rawType = cands.first;

  // 3) data de agendamento (início)
  final idx = lines.indexWhere((l) => norm(l).startsWith('data de agendamento'));
  if (idx >= 0) {
    for (var j = idx; j < math.min(idx + 3, lines.length); j++) {
      final d = parseDate(lines[j]);
      if (d != null) {
        r.date = d;
        break;
      }
    }
  }
  return r;
}

// ───────────────────────── CSV do Elleven ─────────────────────────
class ImportRow {
  final String p;
  final String rawType;
  final String key;
  final DateTime? closed;
  final DateTime? opened;
  ImportRow(this.p, this.rawType, this.closed, this.opened) : key = norm(rawType);
}

List<String> splitCsv(String line, String delim) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQ = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQ && i + 1 < line.length && line[i + 1] == '"') {
        sb.write('"');
        i++;
      } else {
        inQ = !inQ;
      }
    } else if (ch == delim && !inQ) {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(ch);
    }
  }
  out.add(sb.toString());
  return out;
}

/// Lê a "Listagem de Solicitações" do Elleven. Devolve null se o texto não tiver esse formato.
List<ImportRow>? parseElleven(String text) {
  final lines = text.replaceAll('\ufeff', '').split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  final hi = lines.indexWhere((l) {
    final n = norm(l);
    return n.contains('protocolo') && n.contains('tipo de solicitacao');
  });
  if (hi < 0) return null;
  final hl = lines[hi];
  final delim = ';'.allMatches(hl).length >= ','.allMatches(hl).length ? ';' : ',';
  final head = splitCsv(hl, delim).map(norm).toList();
  final cP = head.indexWhere((h) => h == 'protocolo');
  final cT = head.indexWhere((h) => h.startsWith('tipo de solicitacao'));
  final cE = head.indexWhere((h) => h.contains('encerramento'));
  final cA = head.indexWhere((h) => h.contains('abertura'));
  if (cP < 0 || cT < 0) return null;
  final rows = <ImportRow>[];
  for (final l in lines.skip(hi + 1)) {
    final f = splitCsv(l, delim);
    String at(int i) => (i >= 0 && i < f.length) ? f[i].trim() : '';
    final p = at(cP).replaceAll(RegExp(r'\D'), '');
    if (p.isEmpty) continue;
    rows.add(ImportRow(p, at(cT), cE >= 0 ? parseDate(at(cE)) : null, cA >= 0 ? parseDate(at(cA)) : null));
  }
  return rows;
}

String shortType(String raw) => raw.replaceFirst(RegExp(r'^O&M\s*-?\s*'), '');

// ───────────────────────── app ─────────────────────────
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meus Protocolos',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(seedColor: kAcc1, brightness: Brightness.dark, surface: kCard),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SharedPreferences? prefs;
  final Map<String, Proto> items = {};
  double upValue = 4.20;
  double goal = 0;
  int tab = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String query = '';
  bool reading = false;
  final searchCtl = TextEditingController();
  final upCtl = TextEditingController();
  final goalCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // prints compartilhados de outro app (ex.: Voalle → Compartilhar → Meus Protocolos)
    _share.setMethodCallHandler((call) async {
      if (call.method == 'shared') await _checkShared();
      return null;
    });
    _load();
  }

  static const _share = MethodChannel('protocolos/share');

  Future<void> _checkShared() async {
    if (prefs == null || reading) return;
    List<String> paths;
    try {
      final r = await _share.invokeMethod<List<dynamic>>('getShared');
      paths = (r ?? const []).map((e) => '$e').toList();
    } catch (_) {
      return;
    }
    if (paths.isNotEmpty && mounted) {
      setState(() => tab = 0);
      await _processShots(paths);
    }
    List<String> csvs;
    try {
      final r = await _share.invokeMethod<List<dynamic>>('getSharedCsv');
      csvs = (r ?? const []).map((e) => '$e').toList();
    } catch (_) {
      return;
    }
    for (final t in csvs) {
      if (!mounted) return;
      await _importCsvText(t);
    }
  }

  Map<String, String> _loadTypeMap() {
    try {
      final raw = prefs?.getString('typeMap');
      if (raw == null) return {};
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _pickCsvFile() async {
    String? text;
    try {
      text = await _share.invokeMethod<String>('pickCsv');
    } catch (e) {
      _snack('Não consegui abrir o arquivo: $e');
      return;
    }
    if (text == null || !mounted) return;
    await _importCsvText(text);
  }

  Future<void> _importCsvText(String text) async {
    final rows = parseElleven(text);
    if (rows == null) {
      await _importGeneric(text);
      return;
    }
    if (rows.isEmpty) {
      _snack('Nenhum protocolo encontrado no arquivo');
      return;
    }
    final res = await Navigator.push<ImportDecision>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPage(
          rows: rows,
          existing: items.keys.toSet(),
          upValue: upValue,
          savedMap: _loadTypeMap(),
        ),
      ),
    );
    if (res == null || !mounted) return;
    final map = _loadTypeMap()..addAll(res.mapping);
    await prefs?.setString('typeMap', jsonEncode(map));
    if (res.protos.isEmpty) {
      _snack('Nada para importar');
      return;
    }
    final before = <String, Proto?>{for (final p in res.protos) p.p: items[p.p]};
    var latest = res.protos.first;
    setState(() {
      for (final p in res.protos) {
        items[p.p] = p;
        if (p.ts > latest.ts) latest = p;
      }
      month = DateTime(latest.date.year, latest.date.month);
      tab = 0;
    });
    await _persist();
    final total = res.protos.fold<double>(0, (s, p) => s + valOf(p));
    _snack('${res.protos.length} protocolo(s) importados · ${brl(total)}', undo: () {
      setState(() {
        before.forEach((k, old) {
          if (old == null) {
            items.remove(k);
          } else {
            items[k] = old;
          }
        });
      });
      _persist();
    });
  }

  @override
  void dispose() {
    searchCtl.dispose();
    upCtl.dispose();
    goalCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('items');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        m.forEach((k, v) => items[k] = Proto.fromJson(Map<String, dynamic>.from(v as Map)));
      } catch (_) {}
    }
    setState(() {
      prefs = p;
      upValue = p.getDouble('upValue') ?? 4.20;
      goal = p.getDouble('goal') ?? 0;
      upCtl.text = num2(upValue);
      goalCtl.text = goal > 0 ? num2(goal) : '0';
    });
    _checkShared();
  }

  Future<void> _persist() async {
    await prefs?.setString('items', jsonEncode(items.map((k, v) => MapEntry(k, v.toJson()))));
  }

  Future<void> _saveCfg() async {
    await prefs?.setDouble('upValue', upValue);
    await prefs?.setDouble('goal', goal);
  }

  double valOf(Proto p) => p.up * upValue;

  List<Proto> get monthItems {
    final l = items.values.where((i) => i.date.year == month.year && i.date.month == month.month).toList();
    l.sort((a, b) => b.ts.compareTo(a.ts));
    return l;
  }

  Map<String, int> get usage {
    final u = <String, int>{};
    for (final i in items.values) {
      u[i.t] = (u[i.t] ?? 0) + 1;
    }
    return u;
  }

  void _put(Proto p, {String? oldKey}) {
    setState(() {
      if (oldKey != null && oldKey != p.p) items.remove(oldKey);
      items[p.p] = p;
    });
    _persist();
  }

  void _del(String key) {
    setState(() => items.remove(key));
    _persist();
  }

  void _snack(String msg, {VoidCallback? undo}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 4),
      action: undo == null ? null : SnackBarAction(label: 'Desfazer', onPressed: undo),
    ));
  }

  Future<void> _openSheet({Proto? edit, ShotResult? shot}) async {
    final res = await showModalBottomSheet<SheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => AddSheet(
        edit: edit,
        shot: shot,
        usage: usage,
        upValue: upValue,
        existing: items.keys.toSet(),
      ),
    );
    if (res == null || !mounted) return;
    if (res.delete && edit != null) {
      final old = edit;
      _del(old.p);
      _snack('Protocolo excluído', undo: () => _put(old));
      return;
    }
    final p = res.save;
    if (p == null) return;
    final wasEdit = edit != null;
    _put(p, oldKey: edit?.p);
    setState(() => month = DateTime(p.date.year, p.date.month));
    _snack(wasEdit ? 'Protocolo atualizado' : '+${brl(valOf(p))} · #${p.p}',
        undo: wasEdit ? null : () => _del(p.p));
  }

  Future<void> _readShots() async {
    List<XFile> files;
    try {
      files = await ImagePicker().pickMultiImage();
    } catch (e) {
      _snack('Não consegui abrir a galeria: $e');
      return;
    }
    if (files.isEmpty || !mounted) return;
    await _processShots(files.map((f) => f.path).toList());
  }

  Future<void> _processShots(List<String> paths) async {
    setState(() => reading = true);
    final results = <ShotResult>[];
    try {
      for (final path in paths) {
        results.add(await readShot(path));
      }
    } catch (e) {
      if (mounted) _snack('Não consegui ler o print: $e');
    }
    if (!mounted) return;
    setState(() => reading = false);

    final ok = results.where((r) => r.proto != null).toList();
    if (ok.isEmpty) {
      _snack('Não achei o número do protocolo no print');
      return;
    }
    if (ok.length == 1) {
      _openSheet(shot: ok.first);
      return;
    }
    // vários prints: salva direto os que foram reconhecidos por completo
    final saved = <String>[];
    ShotResult? pending;
    double total = 0;
    for (final r in ok) {
      if (r.typeIds.length == 1) {
        final t = typeById[r.typeIds.first]!;
        final p = Proto(r.proto!, t.id, t.up, (r.date ?? DateTime.now()).millisecondsSinceEpoch);
        _put(p);
        saved.add(p.p);
        total += valOf(p);
      } else {
        pending ??= r;
      }
    }
    _snack('${saved.length} protocolo(s) salvos · +${brl(total)}', undo: () {
      for (final k in saved) {
        _del(k);
      }
    });
    if (pending != null) {
      final next = pending;
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _openSheet(shot: next);
    }
  }

  // ───────── telas ─────────
  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (prefs == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (tab == 0) {
      body = _home();
    } else if (tab == 1) {
      body = _summary();
    } else {
      body = _settings();
    }
    return Stack(children: [
      Scaffold(
        body: SafeArea(child: body),
        floatingActionButton: tab == 2
            ? null
            : Column(mainAxisSize: MainAxisSize.min, children: [
                FloatingActionButton.small(
                  heroTag: 'shot',
                  backgroundColor: kCard2,
                  foregroundColor: kText,
                  onPressed: _readShots,
                  child: const Icon(Icons.photo_camera_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add',
                  backgroundColor: kAcc1,
                  foregroundColor: kDark,
                  onPressed: () => _openSheet(),
                  child: const Icon(Icons.add, size: 30),
                ),
              ]),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF0E1628),
          indicatorColor: withA(0x10B981, 0x33),
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.list_alt), label: 'Protocolos'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Resumo'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
          ],
        ),
      ),
      if (reading)
        Positioned.fill(
          child: Container(
            color: const Color(0xDD0B1220),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: kAcc1),
                SizedBox(height: 16),
                Material(
                  type: MaterialType.transparency,
                  child: Text('Lendo o print…',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _top() {
    final n = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 0, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Meus Protocolos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('${weekLong[n.weekday % 7]}, ${n.day} de ${monthNames[n.month - 1].toLowerCase()}',
                style: const TextStyle(color: kMuted, fontSize: 13)),
          ]),
        ),
        IconButton(
          tooltip: 'Importar CSV do Elleven',
          onPressed: _pickCsvFile,
          icon: const Icon(Icons.upload_file, color: kMuted),
        ),
      ]),
    );
  }

  Widget _navBtn(String s, VoidCallback onTap) => Material(
        color: const Color(0x29FFFFFF),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
                child: Text(s, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        ),
      );

  Widget _hero() {
    final arr = monthItems;
    final ups = arr.fold<double>(0, (s, i) => s + i.up);
    final val = ups * upValue;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF0891B2), Color(0xFF2563EB)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _navBtn('‹', () => setState(() => month = DateTime(month.year, month.month - 1))),
          Expanded(
            child: Text('${monthNames[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
          ),
          _navBtn('›', () => setState(() => month = DateTime(month.year, month.month + 1))),
        ]),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(brl(val),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
        ),
        const SizedBox(height: 2),
        Text('${num2(ups)} UPs   ·   ${arr.length} protocolos',
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        if (goal > 0) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: math.min(1.0, math.max(0.0, val / goal)),
              minHeight: 9,
              backgroundColor: const Color(0x33000000),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Text('${(val / goal * 100).round()}% da meta de ${brl(goal)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            Text(val >= goal ? 'Meta batida! 🎉' : 'faltam ${brl(goal - val)}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ],
      ]),
    );
  }

  Widget _stat(String l, String v) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w600, letterSpacing: .6)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ]),
      );

  Widget _section(String title, Widget child) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _home() {
    final now = DateTime.now();
    var arr = monthItems;
    final q = norm(query);
    if (q.isNotEmpty) {
      arr = arr.where((i) => norm(i.p).contains(q) || norm(typeById[i.t]?.name ?? i.t).contains(q)).toList();
    }
    final today = items.values.where((i) => sameDay(i.date, now)).toList();
    final tUps = today.fold<double>(0, (s, i) => s + i.up);

    final children = <Widget>[
      _top(),
      _hero(),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _stat('HOJE', '${today.length}')),
        const SizedBox(width: 10),
        Expanded(child: _stat('UPS HOJE', num2(tUps))),
        const SizedBox(width: 10),
        Expanded(child: _stat('R\$ HOJE', num2(tUps * upValue))),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: searchCtl,
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: 'Buscar protocolo ou tipo',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    searchCtl.clear();
                    setState(() => query = '');
                  },
                ),
          filled: true,
          fillColor: kCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    ];

    if (arr.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Column(children: [
          Text(q.isEmpty ? '📋' : '🔎', style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
            q.isEmpty
                ? 'Nenhum protocolo neste mês ainda.\nToque no + ou no 📷 para adicionar.'
                : 'Nenhum protocolo encontrado neste mês.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted),
          ),
        ]),
      ));
    } else {
      String? lastDay;
      final yest = now.subtract(const Duration(days: 1));
      for (final i in arr) {
        final dk = dayKey(i.date);
        if (dk != lastDay) {
          lastDay = dk;
          final dayList = arr.where((x) => dayKey(x.date) == dk).toList();
          final dv = dayList.fold<double>(0, (s, x) => s + valOf(x));
          final lbl = sameDay(i.date, now)
              ? 'Hoje'
              : sameDay(i.date, yest)
                  ? 'Ontem'
                  : '${weekShort[i.date.weekday % 7]}, ${two(i.date.day)} ${monthShort[i.date.month - 1]}';
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Row(children: [
              Expanded(
                  child: Text('$lbl · ${dayList.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Text(brl(dv), style: const TextStyle(color: kAcc1, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ));
        }
        children.add(_itemTile(i));
      }
    }
    children.add(const SizedBox(height: 150));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), children: children);
  }

  Widget _itemTile(Proto i) {
    final t = typeById[i.t];
    final c = catById[t?.cat ?? 'man']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openSheet(edit: i),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              catIcon(c, 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t?.name ?? i.t,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('#${i.p} · ${two(i.date.hour)}:${two(i.date.minute)}',
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(brl(valOf(i)), style: const TextStyle(color: kAcc1, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${num2(i.up)} UP', style: const TextStyle(color: kMuted, fontSize: 11)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final arr = monthItems;
    final now = DateTime.now();
    final byDay = <int, double>{};
    for (final i in arr) {
      byDay[i.date.day] = (byDay[i.date.day] ?? 0) + valOf(i);
    }
    final total = arr.fold<double>(0, (s, i) => s + valOf(i));
    final days = byDay.length;
    double best = 0;
    for (final v in byDay.values) {
      if (v > best) best = v;
    }
    final dim = DateTime(month.year, month.month + 1, 0).day;
    final isCur = now.year == month.year && now.month == month.month;
    final double? proj = total == 0 ? null : (isCur ? total / now.day * dim : total);
    final maxV = math.max(1.0, best);

    final bars = SizedBox(
      height: 140,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var d = 1; d <= dim; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(
                  height: math.max(2.0, (byDay[d] ?? 0) / maxV * 112),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    color: (byDay[d] ?? 0) == 0 ? kLine : null,
                    gradient: (byDay[d] ?? 0) == 0
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: (isCur && d == now.day)
                                ? const [Color(0xFFFDE047), Color(0xFFF59E0B)]
                                : const [kAcc2, kAcc1],
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 12,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text((d % 5 == 1 || d == dim) ? '$d' : '',
                        style: const TextStyle(fontSize: 9, color: kDim)),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );

    final byCat = <String, double>{};
    for (final i in arr) {
      final c = typeById[i.t]?.cat ?? 'man';
      byCat[c] = (byCat[c] ?? 0) + valOf(i);
    }
    final catEntries = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final catTot = total == 0 ? 1.0 : total;

    final byT = <String, List<double>>{};
    for (final i in arr) {
      final e = byT.putIfAbsent(i.t, () => [0.0, 0.0]);
      e[0] += 1;
      e[1] += i.up;
    }
    final tEntries = byT.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
    final tMax = tEntries.isEmpty ? 1.0 : tEntries.first.value[1];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 150), children: [
      _top(),
      _hero(),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _stat('DIAS TRABALHADOS', '$days')),
        const SizedBox(width: 10),
        Expanded(child: _stat('MÉDIA POR DIA', days == 0 ? 'R\$ 0' : brl(total / days))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _stat('MELHOR DIA', best == 0 ? '—' : brl(best))),
        const SizedBox(width: 10),
        Expanded(child: _stat('PREVISÃO DO MÊS', proj == null ? '—' : brl(proj))),
      ]),
      _section('R\$ por dia', bars),
      _section(
        'Por categoria',
        catEntries.isEmpty
            ? const Text('Sem dados neste mês', style: TextStyle(color: kMuted))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 14,
                    child: Row(children: [
                      for (final e in catEntries)
                        Expanded(
                          flex: math.max(1, (e.value / catTot * 1000).round()),
                          child: Container(color: catById[e.key]!.color),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  for (final e in catEntries)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: catById[e.key]!.color, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 6),
                      Text('${catById[e.key]!.name} · ${(e.value / catTot * 100).round()}%',
                          style: const TextStyle(color: kMuted, fontSize: 12)),
                    ]),
                ]),
              ]),
      ),
      _section(
        'Por tipo de serviço',
        tEntries.isEmpty
            ? const Text('Sem protocolos neste mês', style: TextStyle(color: kMuted))
            : Column(children: [
                for (final e in tEntries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                          child: Text(typeById[e.key]?.name ?? e.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text('${e.value[0].round()}× · ${brl(e.value[1] * upValue)}',
                            style: const TextStyle(fontSize: 13, color: kMuted)),
                      ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 8,
                          color: kBg,
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: math.max(0.02, e.value[1] / tMax),
                            child: Container(color: catById[typeById[e.key]?.cat ?? 'man']!.color),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
      ),
    ]);
  }

  Widget _setRow(String title, String sub, TextEditingController ctl, void Function(double) onValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
          ]),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: ctl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
            onChanged: (s) {
              final v = parseNum(s);
              if (v != null) onValue(v);
            },
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: kBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool danger = false}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: danger ? const Color(0x1FEF4444) : kCard2,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, color: danger ? const Color(0xFFFCA5A5) : kText)),
            ),
          ),
        ),
      );

  Widget _settings() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
      _top(),
      _section(
        'Valores',
        Column(children: [
          _setRow('Valor da UP (R\$)', 'Usado em todos os cálculos', upCtl, (v) {
            if (v > 0) {
              setState(() => upValue = v);
              _saveCfg();
            }
          }),
          const Divider(color: kLine),
          _setRow('Meta do mês (R\$)', 'Deixe 0 para esconder a barra', goalCtl, (v) {
            setState(() => goal = v < 0 ? 0 : v);
            _saveCfg();
          }),
        ]),
      ),
      _section(
        'Backup',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _btn('📂  Importar arquivo do Elleven (CSV)', _pickCsvFile),
          _btn('📋  Copiar CSV do mês', _copyCsv),
          _btn('📥  Colar / importar CSV', _importDialog),
          _btn('🗑️  Apagar protocolos do mês', _wipeMonth, danger: true),
          const SizedBox(height: 10),
          const Text(
            'Os protocolos ficam salvos neste celular. De vez em quando copie o CSV e guarde '
            '(WhatsApp, e-mail, Drive) como backup.',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
          ),
        ]),
      ),
      _section(
        'Tabela de UPs',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final c in cats) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text('${c.emoji} ${c.name.toUpperCase()}',
                  style: TextStyle(color: c.color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            for (final t in types.where((t) => t.cat == c.id))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(t.name, style: const TextStyle(fontSize: 13))),
                  Text('${num2(t.up)} UP · ${brl(t.up * upValue)}',
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                ]),
              ),
          ],
        ]),
      ),
    ]);
  }

  Future<void> _copyCsv() async {
    final arr = monthItems..sort((a, b) => a.ts.compareTo(b.ts));
    final rows = <String>[
      'protocolo;tipo;data;hora;ups;valor',
      for (final i in arr)
        '${i.p};${typeById[i.t]?.name ?? i.t};${two(i.date.day)}/${two(i.date.month)}/${i.date.year};'
            '${two(i.date.hour)}:${two(i.date.minute)};${num2(i.up)};${num2(valOf(i))}',
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    _snack('CSV de ${arr.length} protocolo(s) copiado');
  }

  Future<void> _importDialog() async {
    final ctl = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip != null && clip.text != null) ctl.text = clip.text!;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Importar CSV'),
        content: TextField(
          controller: ctl,
          minLines: 4,
          maxLines: 8,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(hintText: 'protocolo;tipo;data', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importar')),
        ],
      ),
    );
    if (ok != true) return;
    await _importCsvText(ctl.text);
  }

  Future<void> _importGeneric(String text) async {
    var n = 0;
    var skip = 0;
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final parts = l.split(RegExp(r'[;,\t]')).map((s) => s.trim().replaceAll('"', '')).toList();
      final p = parts.first;
      final ids = matchType(l);
      if (p.isEmpty || ids.isEmpty || norm(p).contains('protocolo')) {
        skip++;
        continue;
      }
      final t = typeById[ids.first]!;
      final d = parseDate(l) ?? DateTime.now();
      items[p] = Proto(p, t.id, t.up, d.millisecondsSinceEpoch);
      n++;
    }
    setState(() {});
    await _persist();
    _snack('$n importado(s)${skip > 0 ? ' · $skip linha(s) ignorada(s)' : ''}');
  }

  Future<void> _wipeMonth() async {
    final arr = monthItems;
    if (arr.isEmpty) {
      _snack('Nada para apagar neste mês');
      return;
    }
    final name = '${monthNames[month.month - 1]} ${month.year}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text('Apagar $name?'),
        content: Text('Isso remove ${arr.length} protocolo(s) de $name. Não dá para desfazer — '
            'copie o CSV antes se quiser guardar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      for (final i in arr) {
        items.remove(i.p);
      }
    });
    await _persist();
    _snack('Mês apagado');
  }
}

// ───────────────────────── tela de adicionar / editar ─────────────────────────
class SheetResult {
  final Proto? save;
  final bool delete;
  const SheetResult({this.save, this.delete = false});
}

class AddSheet extends StatefulWidget {
  final Proto? edit;
  final ShotResult? shot;
  final Map<String, int> usage;
  final double upValue;
  final Set<String> existing;
  const AddSheet({
    super.key,
    this.edit,
    this.shot,
    required this.usage,
    required this.upValue,
    required this.existing,
  });

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final protoCtl = TextEditingController();
  String? type;
  String catFilter = 'top';
  DateTime date = DateTime.now();
  bool fromShot = false;
  bool reading = false;
  String? hint;
  List<String> candidates = [];

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      protoCtl.text = e.p;
      type = e.t;
      date = e.date;
      catFilter = 'all';
    }
    final s = widget.shot;
    if (s != null) _applyShot(s);
  }

  @override
  void dispose() {
    protoCtl.dispose();
    super.dispose();
  }

  void _applyShot(ShotResult r) {
    fromShot = true;
    if (r.proto != null) protoCtl.text = r.proto!;
    if (r.date != null) date = r.date!;
    if (r.typeIds.length == 1) {
      type = r.typeIds.first;
      catFilter = typeById[r.typeIds.first]!.cat;
      candidates = [];
      hint = null;
    } else if (r.typeIds.length > 1) {
      type = null;
      candidates = r.typeIds;
      catFilter = 'cand';
      hint = 'O print diz "${r.rawType}". Escolha qual destes:';
    } else {
      type = null;
      candidates = [];
      catFilter = 'all';
      hint = r.rawType.isEmpty
          ? 'Não consegui ler o tipo — escolha na lista.'
          : 'Tipo "${r.rawType}" não reconhecido — escolha na lista.';
    }
  }

  Future<void> _readShot() async {
    XFile? f;
    try {
      f = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (e) {
      setState(() => hint = 'Não consegui abrir a galeria: $e');
      return;
    }
    if (f == null) return;
    setState(() => reading = true);
    try {
      final r = await readShot(f.path);
      if (!mounted) return;
      setState(() {
        reading = false;
        if (r.proto == null) {
          hint = 'Não achei o número do protocolo nesse print.';
        } else {
          _applyShot(r);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          reading = false;
          hint = 'Erro ao ler o print: $e';
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(date));
    if (!mounted) return;
    setState(() => date = DateTime(d.year, d.month, d.day, tm?.hour ?? date.hour, tm?.minute ?? date.minute));
  }

  List<SType> get shown {
    if (catFilter == 'top') {
      final l = [...types];
      l.sort((a, b) {
        final c = (widget.usage[b.id] ?? 0).compareTo(widget.usage[a.id] ?? 0);
        return c != 0 ? c : types.indexOf(a).compareTo(types.indexOf(b));
      });
      return l.take(6).toList();
    }
    if (catFilter == 'all') return types;
    if (catFilter == 'cand') return [for (final id in candidates) if (typeById[id] != null) typeById[id]!];
    return types.where((t) => t.cat == catFilter).toList();
  }

  Widget _lbl(String s, {bool badge = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Row(children: [
          Text(s, style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600, letterSpacing: .6)),
          if (badge)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kAcc2, borderRadius: BorderRadius.circular(99)),
              child: const Text('lido do print',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kDark)),
            ),
        ]),
      );

  Widget _shotButton() => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton.icon(
            onPressed: reading ? null : _readShot,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(reading ? 'Lendo o print…' : 'Preencher com print da tela'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAcc2,
              side: const BorderSide(color: kAcc2, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          if (reading) const Padding(padding: EdgeInsets.only(top: 6), child: LinearProgressIndicator(color: kAcc2)),
        ]),
      );

  Widget _typeTile(SType ty) {
    final c = catById[ty.cat]!;
    final on = ty.id == type;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: on ? kAcc1 : Colors.transparent, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: on ? withA(0x10B981, 0x1F) : kBg,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => setState(() {
            type = ty.id;
            hint = null;
          }),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              catIcon(c, 34),
              const SizedBox(width: 10),
              Expanded(child: Text(ty.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(brl(ty.up * widget.upValue), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${num2(ty.up)} UP', style: const TextStyle(fontSize: 12, color: kMuted)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = protoCtl.text.trim();
    final dup = p.isNotEmpty && widget.existing.contains(p) && p != widget.edit?.p;
    final SType? t = type == null ? null : typeById[type];
    final mq = MediaQuery.of(context);
    final chips = <(String, String)>[
      if (candidates.isNotEmpty) ('cand', '❓ Opções do print'),
      ('top', '⭐ Mais usados'),
      ('all', 'Todos'),
      for (final c in cats) (c.id, '${c.emoji} ${c.name}'),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(9)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
            child: Row(children: [
              Expanded(
                child: Text(widget.edit == null ? 'Novo protocolo' : 'Editar protocolo',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: kMuted)),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              children: [
                if (widget.edit == null) _shotButton(),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(hint!, style: const TextStyle(color: kWarn, fontSize: 13)),
                  ),
                _lbl('NÚMERO DO PROTOCOLO', badge: fromShot),
                TextField(
                  controller: protoCtl,
                  keyboardType: TextInputType.number,
                  autofocus: widget.edit == null && widget.shot == null,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: 'Ex: 1234567',
                    filled: true,
                    fillColor: kBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine)),
                  ),
                ),
                if (dup)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('⚠️ Esse protocolo já está salvo — salvar vai substituir.',
                        style: TextStyle(color: kWarn, fontSize: 12)),
                  ),
                _lbl('TIPO DE SERVIÇO'),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final c in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.$2),
                          selected: catFilter == c.$1,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => catFilter = c.$1),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                for (final ty in shown) _typeTile(ty),
                _lbl('DATA E HORA'),
                Material(
                  color: kBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const Icon(Icons.event, color: kMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              '${two(date.day)}/${two(date.month)}/${date.year}  ${two(date.hour)}:${two(date.minute)}',
                              style: const TextStyle(fontSize: 16)),
                        ),
                        const Text('alterar', style: TextStyle(color: kAcc2, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
                if (widget.edit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, const SheetResult(delete: true)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFCA5A5)),
                      child: const Text('Excluir protocolo'),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: kLine))),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kAcc1,
                  foregroundColor: kDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (p.isEmpty || t == null)
                    ? null
                    : () => Navigator.pop(
                          context,
                          SheetResult(save: Proto(p, t.id, t.up, date.millisecondsSinceEpoch)),
                        ),
                child: Text(
                  t == null ? 'Escolha o tipo' : 'Salvar  ·  +${brl(t.up * widget.upValue)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── tela de importação do Elleven ─────────────────────────
class ImportDecision {
  final List<Proto> protos;
  final Map<String, String> mapping;
  ImportDecision(this.protos, this.mapping);
}

class ImportPage extends StatefulWidget {
  final List<ImportRow> rows;
  final Set<String> existing;
  final double upValue;
  final Map<String, String> savedMap;
  const ImportPage({
    super.key,
    required this.rows,
    required this.existing,
    required this.upValue,
    required this.savedMap,
  });

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final Map<String, String?> choice = {}; // tipo do Elleven → id do app, 'skip' ou null (falta escolher)
  final Map<String, String> rawOf = {};
  final Map<String, int> countOf = {};
  bool onlyClosed = true;
  bool overwrite = false;

  @override
  void initState() {
    super.initState();
    for (final r in widget.rows) {
      rawOf.putIfAbsent(r.key, () => r.rawType);
      countOf[r.key] = (countOf[r.key] ?? 0) + 1;
    }
    for (final k in rawOf.keys) {
      final saved = widget.savedMap[k];
      if (saved != null && (saved == 'skip' || typeById.containsKey(saved))) {
        choice[k] = saved;
      } else {
        final ids = matchType(rawOf[k]!);
        choice[k] = ids.length == 1 ? ids.first : null;
      }
    }
  }

  Future<void> _choose(String k) async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          Text(shortType(rawOf[k]!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Qual tipo da tabela de UPs é esse?', style: TextStyle(color: kMuted)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.block, color: Color(0xFFFCA5A5)),
            title: const Text('Não contar (ignorar esse tipo)'),
            onTap: () => Navigator.pop(ctx, 'skip'),
          ),
          for (final c in cats) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text('${c.emoji} ${c.name.toUpperCase()}',
                  style: TextStyle(color: c.color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            for (final t in types.where((t) => t.cat == c.id))
              ListTile(
                dense: true,
                selected: choice[k] == t.id,
                title: Text(t.name),
                trailing: Text('${num2(t.up)} UP', style: const TextStyle(color: kMuted)),
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ]),
      ),
    );
    if (sel != null) setState(() => choice[k] = sel);
  }

  @override
  Widget build(BuildContext context) {
    final out = <String, Proto>{};
    var existingSkip = 0, openSkip = 0, ignored = 0, missing = 0;
    for (final r in widget.rows) {
      final c = choice[r.key];
      if (c == null) {
        missing++;
        continue;
      }
      if (c == 'skip') {
        ignored++;
        continue;
      }
      final d = onlyClosed ? r.closed : (r.closed ?? r.opened);
      if (d == null) {
        openSkip++;
        continue;
      }
      if (!overwrite && widget.existing.contains(r.p)) {
        existingSkip++;
        continue;
      }
      final t = typeById[c]!;
      out[r.p] = Proto(r.p, t.id, t.up, d.millisecondsSinceEpoch);
    }
    final protos = out.values.toList();
    final total = protos.fold<double>(0, (s, p) => s + p.up * widget.upValue);

    // resumo por mês
    final byMonth = <String, List<double>>{};
    for (final p in protos) {
      final k = '${p.date.year}-${two(p.date.month)}';
      final e = byMonth.putIfAbsent(k, () => [0.0, 0.0]);
      e[0] += 1;
      e[1] += p.up * widget.upValue;
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    final keys = rawOf.keys.toList()
      ..sort((a, b) {
        final ua = choice[a] == null ? 0 : 1, ub = choice[b] == null ? 0 : 1;
        if (ua != ub) return ua.compareTo(ub);
        return (countOf[b] ?? 0).compareTo(countOf[a] ?? 0);
      });

    final notes = <String>[
      if (existingSkip > 0) '$existingSkip já estavam no app (pulados)',
      if (openSkip > 0) '$openSkip ainda não encerrados (pulados)',
      if (ignored > 0) '$ignored de tipos ignorados',
      if (missing > 0) '$missing de tipos sem escolha (pulados)',
    ];

    return Scaffold(
      appBar: AppBar(backgroundColor: kBg, title: const Text('Importar do Elleven')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF0891B2), Color(0xFF2563EB)],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.rows.length} protocolos no arquivo', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 6),
            Text('${protos.length} para importar',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            Text(brl(total), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            for (final m in months)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${monthNames[int.parse(m.substring(5)) - 1]} ${m.substring(0, 4)}: '
                  '${byMonth[m]![0].round()} · ${brl(byMonth[m]![1])}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
          ]),
        ),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(notes.join('  ·  '), style: const TextStyle(color: kMuted, fontSize: 12)),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: onlyClosed,
          onChanged: (v) => setState(() => onlyClosed = v),
          title: const Text('Só protocolos encerrados'),
          subtitle: const Text('Usa a data do encerramento', style: TextStyle(color: kMuted, fontSize: 12)),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: overwrite,
          onChanged: (v) => setState(() => overwrite = v),
          title: const Text('Substituir os que já existem'),
          subtitle: const Text('Desligado: mantém o que você já lançou', style: TextStyle(color: kMuted, fontSize: 12)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text('TIPOS ENCONTRADOS',
              style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600, letterSpacing: .6)),
        ),
        for (final k in keys) _groupTile(k),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text('Toque num tipo para trocar. O app lembra suas escolhas na próxima importação.',
              style: TextStyle(color: kMuted, fontSize: 12)),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kAcc1,
                foregroundColor: kDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final mapping = <String, String>{};
                choice.forEach((k, v) {
                  if (v != null) mapping[k] = v;
                });
                Navigator.pop(context, ImportDecision(protos, mapping));
              },
              child: Text(
                protos.isEmpty ? 'Salvar escolhas' : 'Importar ${protos.length} protocolos',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupTile(String k) {
    final c = choice[k];
    final missing = c == null;
    final t = (c == null || c == 'skip') ? null : typeById[c];
    final cat = t == null ? null : catById[t.cat];
    final sub = missing
        ? 'Toque para escolher o tipo'
        : c == 'skip'
            ? 'Não conta UP (ignorado)'
            : '→ ${t!.name} · ${num2(t.up)} UP';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: missing ? kWarn : Colors.transparent, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: kCard,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => _choose(k),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              cat != null
                  ? catIcon(cat, 38)
                  : Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(13)),
                      child: Text(missing ? '❓' : '🚫', style: const TextStyle(fontSize: 17)),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shortType(rawOf[k]!), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: missing ? kWarn : kMuted, fontSize: 12)),
                ]),
              ),
              Text('${countOf[k]}×', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right, color: kMuted),
            ]),
          ),
        ),
      ),
    );
  }
}
