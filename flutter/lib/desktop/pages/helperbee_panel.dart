// HelperBee home inside the HelperBee Remote client (added by branding/rustdesk/apply-branding.py).
// Three sections, assistance first so that anyone can ask for help at once:
//   1. Request assistance  (notes for the technician, the ID of this PC)
//   2. Control a remote desktop (the RustDesk home page, plus the HelperBee devices on technician PCs)
//   3. Settings (HelperBee server, RustDesk ID/relay server)
// Data comes from the local HelperBee agent API (127.0.0.1:47123, same data as the tray popup). Changing the
// HelperBee server runs "helperbee-agent set-server", which asks Windows for administrator rights.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _api = 'http://127.0.0.1:47123';
const _hdr = {'X-HelperBee': 'tray'};
const hbRed = Color(0xFFEF443B);
const hbRedDeep = Color(0xFFB8322B);
const _names = {'anydesk': 'AnyDesk', 'rustdesk': 'HelperBee Remote', 'teamviewer': 'TeamViewer', 'supremo': 'Supremo', 'workerbee': 'workerBee (Hive)'};

final bool _it = Platform.localeName.toLowerCase().startsWith('it');
String _t(String en, String it) => _it ? it : en;

Future<Map<String, dynamic>?> hbStatus() async {
  try {
    final r = await http.get(Uri.parse('$_api/status'), headers: _hdr).timeout(const Duration(seconds: 3));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
  } catch (_) {}
  return null;
}

String _ago(dynamic ms) {
  if (ms is! num || ms == 0) return '—';
  final s = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms.toInt())).inSeconds;
  if (s < 60) return '$s s';
  if (s < 3600) return '${s ~/ 60} min';
  if (s < 86400) return '${s ~/ 3600} h';
  return '${s ~/ 86400} ${_t('d', 'g')}';
}

final _safeId = RegExp(r'^[A-Za-z0-9._@-]{1,43}$');

/// Technician PCs: ask the agent for the target ID + freshly rotated password, then open the client.
/// RustDesk: this same executable with --connect (the running instance takes it). AnyDesk: password on stdin.
Future<String?> hbConnect(int deviceId, String app) async {
  try {
    final r = await http
        .post(Uri.parse('$_api/connect'), headers: {..._hdr, 'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': deviceId, 'app': app, 'user': Platform.environment['USERNAME'] ?? ''}))
        .timeout(const Duration(seconds: 90));
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) return (j is Map && j['error'] != null) ? '${j['error']}' : 'HTTP ${r.statusCode}';
    final id = '${j['remote_id'] ?? ''}', pw = '${j['password'] ?? ''}';
    if (!_safeId.hasMatch(id)) return 'invalid remote ID';
    if (app == 'rustdesk') {
      await Process.start(Platform.resolvedExecutable, ['--connect', id, if (pw.isNotEmpty) ...['--password', pw]], mode: ProcessStartMode.detached);
    } else {
      final pf86 = Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)', pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final exe = ['$pf86\\AnyDesk\\AnyDesk.exe', '$pf\\AnyDesk\\AnyDesk.exe'].firstWhere((e) => File(e).existsSync(), orElse: () => '');
      if (exe.isEmpty) return _t('AnyDesk is not installed on this PC', 'AnyDesk non è installato su questo PC');
      final p = await Process.start(exe, [id, if (pw.isNotEmpty) '--with-password']);
      if (pw.isNotEmpty) {
        p.stdin.writeln(pw);
        await p.stdin.close();
      }
    }
    return null;
  } catch (e) {
    return _t('the HelperBee agent did not answer', "l'agent HelperBee non risponde");
  }
}

String _fmtId(String id) => id.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

void _open(String url) {
  launchUrl(Uri.parse(url)).catchError((_) => false);
}

/// The HelperBee mark (Hive hexagon + hexagonal lifebuoy) drawn in code: no asset needed.
class HelperBeeMark extends StatelessWidget {
  final double size;
  const HelperBeeMark({super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MarkPainter(Theme.of(context).colorScheme.surface));
}

class _MarkPainter extends CustomPainter {
  final Color inner;
  _MarkPainter(this.inner);
  Path _hex(double cx, double cy, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = (-90 + 60 * i) * math.pi / 180;
      final x = cx + r * math.cos(a), y = cy + r * math.sin(a);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 64);
    c.drawPath(_hex(32, 32, 30), Paint()..color = hbRed);
    c.drawPath(_hex(32, 32, 23), Paint()..color = inner);
    for (var i = 0; i < 6; i++) {
      final a1 = (-90 + 60 * i) * math.pi / 180, a2 = (-90 + 60 * (i + 1)) * math.pi / 180;
      final p = Path()
        ..moveTo(32 + 15.5 * math.cos(a1), 32 + 15.5 * math.sin(a1))
        ..lineTo(32 + 15.5 * math.cos(a2), 32 + 15.5 * math.sin(a2))
        ..lineTo(32 + 8 * math.cos(a2), 32 + 8 * math.sin(a2))
        ..lineTo(32 + 8 * math.cos(a1), 32 + 8 * math.sin(a1))
        ..close();
      c.drawPath(p, Paint()..color = i.isEven ? hbRedDeep : Colors.white);
    }
    final outline = Paint()
      ..color = hbRedDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    c.drawPath(_hex(32, 32, 15.5), outline);
    c.drawPath(_hex(32, 32, 8), outline);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.inner != inner;
}

/// The home page of HelperBee Remote: section bar, the selected section, credits.
class HelperBeeHome extends StatefulWidget {
  final Widget remote; // the RustDesk home page (this desktop + connect to a remote desktop)
  final VoidCallback? onNetworkSettings; // RustDesk settings → Network
  const HelperBeeHome({super.key, required this.remote, this.onNetworkSettings});
  @override
  State<HelperBeeHome> createState() => _HelperBeeHomeState();
}

class _HelperBeeHomeState extends State<HelperBeeHome> {
  int tab = 0; // assistance first
  Map<String, dynamic>? st;
  bool loaded = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await hbStatus();
    if (mounted) setState(() { st = s; loaded = true; });
  }

  Widget _tab(int i, IconData icon, String label) {
    final sel = tab == i;
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
      child: sel
          ? FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: hbRed, foregroundColor: Colors.white),
              onPressed: () => setState(() => tab = i),
              icon: Icon(icon, size: 18),
              label: Text(label))
          : OutlinedButton.icon(onPressed: () => setState(() => tab = i), icon: Icon(icon, size: 18), label: Text(label)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    final ok = s?['connected'] == true;
    final pending = s?['info']?['pending_approval'] == true;
    final label = !loaded
        ? '…'
        : s == null
            ? _t('HelperBee agent not running', 'Agent HelperBee non attivo')
            : pending
                ? _t('Waiting for approval', 'In attesa di approvazione')
                : ok
                    ? _t('Connected', 'Connesso')
                    : _t('Server unreachable', 'Server non raggiungibile');
    final dot = s == null ? Colors.grey : pending ? Colors.orange : ok ? Colors.green : hbRed;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const HelperBeeMark(size: 30),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('HelperBee Remote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(alignment: WrapAlignment.end, children: [
              _tab(0, Icons.support_agent, _t('Request assistance', 'Richiedi assistenza')),
              _tab(1, Icons.desktop_windows_outlined, _t('Control a remote desktop', 'Controlla un desktop remoto')),
              _tab(2, Icons.settings_outlined, _t('Settings', 'Impostazioni')),
            ]),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: IndexedStack(index: tab, children: [
          _AssistPage(st: s, loaded: loaded, reload: _load),
          _RemotePage(st: s, remote: widget.remote),
          _SettingsPage(st: s, reload: _load, onNetworkSettings: widget.onNetworkSettings),
        ]),
      ),
      const Divider(height: 1),
      const _Credits(),
    ]);
  }
}

/// Credits line: RustDesk (AGPL-3.0, the base of this client) on the left, pBielli on the right.
class _Credits extends StatelessWidget {
  const _Credits();
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(children: [
        InkWell(
          onTap: () => _open('https://rustdesk.com'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SvgPicture.asset('assets/rustdesk.svg', width: 13, height: 13),
            const SizedBox(width: 6),
            Text(_t('Powered by RustDesk', 'Alimentato da RustDesk'), style: style),
          ]),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _open('https://pbielli.com'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_t('HelperBee by ', 'HelperBee di '), style: style),
            Image.asset('assets/pbielli.png', width: 15, height: 15, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            const SizedBox(width: 5),
            const Text('pBielli · pbielli.com', style: style),
          ]),
        ),
      ]),
    );
  }
}

Widget _centered(Widget child, {double width = 580}) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child)),
    );

Widget _note(BuildContext context, Color color, IconData icon, String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(.4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    );

// ---------------------------------------------------------------- 1. assistance
class _AssistPage extends StatefulWidget {
  final Map<String, dynamic>? st;
  final bool loaded;
  final Future<void> Function() reload;
  const _AssistPage({required this.st, required this.loaded, required this.reload});
  @override
  State<_AssistPage> createState() => _AssistPageState();
}

class _AssistPageState extends State<_AssistPage> {
  final msg = TextEditingController();
  bool sending = false;
  String? result;
  bool resultOk = false;
  bool copied = false;

  @override
  void dispose() {
    msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() { sending = true; result = null; });
    try {
      final r = await http
          .post(Uri.parse('$_api/assist'), headers: {..._hdr, 'Content-Type': 'application/json'},
              body: jsonEncode({'Message': msg.text.trim(), 'User': Platform.environment['USERNAME'] ?? ''}))
          .timeout(const Duration(seconds: 25));
      resultOk = r.statusCode == 200;
      if (resultOk) {
        result = _t('Request sent: a technician has been notified and will contact you.', 'Richiesta inviata: un tecnico è stato avvisato e ti contatterà.');
        msg.clear();
      } else {
        var why = 'HTTP ${r.statusCode}';
        try {
          why = '${jsonDecode(r.body)['error'] ?? why}';
        } catch (_) {}
        result = _t('Could not send the request ($why). Try again in a minute.', 'Invio non riuscito ($why). Riprova tra un minuto.');
      }
    } catch (_) {
      resultOk = false;
      result = _t('Could not send: the HelperBee service is not running. Restart the PC and try again.',
          'Invio non riuscito: il servizio HelperBee non è attivo. Riavvia il PC e riprova.');
    }
    if (mounted) setState(() => sending = false);
    widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.st;
    final info = s?['info'] as Map<String, dynamic>?;
    final assist = info?['assist'] as Map<String, dynamic>?;
    final open = assist != null && assist['status'] == 'open';
    final reply = '${assist?['reply'] ?? ''}';
    final rd = (s?['anydesk']?['apps']?['rustdesk']) as Map<String, dynamic>?;
    String id = '${rd?['id'] ?? ''}';
    if (id.isEmpty) id = '${s?['anydesk']?['id'] ?? ''}';
    final title = Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);
    return _centered(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.support_agent, color: hbRed, size: 40),
        const SizedBox(width: 12),
        Expanded(child: Text(_t('Need help?', 'Hai bisogno di aiuto?'), style: title)),
      ]),
      const SizedBox(height: 8),
      Text(_t('Write what is happening (if you like) and press the red button: a technician receives the request and contacts you.',
          'Scrivi cosa succede (se vuoi) e premi il pulsante rosso: un tecnico riceve la richiesta e ti contatta.')),
      const SizedBox(height: 16),
      if (widget.loaded && s == null)
        _note(context, Colors.orange, Icons.warning_amber_rounded,
            _t('The HelperBee service is not answering on this PC. Restart the PC; if it keeps happening, call your technician.',
                'Il servizio HelperBee non risponde su questo PC. Riavvia il PC; se succede ancora, chiama il tuo tecnico.')),
      if (info?['pending_approval'] == true)
        _note(context, Colors.orange, Icons.hourglass_top, _t('This PC is waiting for a technician to approve it.', 'Questo PC è in attesa di approvazione da parte di un tecnico.')),
      if (open)
        _note(context, Colors.green, Icons.check_circle_outline,
            _t('Assistance requested ${_ago(assist['created_at'])} ago: a technician will contact you. You can add details below.',
                'Assistenza richiesta ${_ago(assist['created_at'])} fa: un tecnico ti contatterà. Puoi aggiungere dettagli qui sotto.')),
      if (reply.isNotEmpty) _note(context, Colors.blue, Icons.chat_bubble_outline, '${_t('Technician', 'Tecnico')}: $reply'),
      TextField(
        controller: msg,
        minLines: 3,
        maxLines: 6,
        maxLength: 1000,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: _t('Notes for the technician (optional)', 'Note per il tecnico (facoltative)'),
          hintText: _t('e.g. the printer does not print, an error appears when I open the mail…', 'es. la stampante non stampa, compare un errore quando apro la posta…'),
          alignLabelWithHint: true,
        ),
      ),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: hbRed, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          onPressed: sending || s == null ? null : _send,
          icon: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.support_agent),
          label: Text(open ? _t('Send more details', 'Invia altri dettagli') : _t('Request assistance', 'Richiedi assistenza')),
        ),
      ),
      if (result != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(result!, style: TextStyle(color: resultOk ? Colors.green : hbRed, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 22),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.5), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('Code of this PC', 'Codice di questo PC'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Row(children: [
            Expanded(child: SelectableText(id.isEmpty ? '—' : _fmtId(id), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
            if (id.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: id));
                  if (!mounted) return;
                  setState(() => copied = true);
                  Timer(const Duration(seconds: 2), () { if (mounted) setState(() => copied = false); });
                },
                icon: Icon(copied ? Icons.check : Icons.copy, size: 16),
                label: Text(copied ? _t('Copied', 'Copiato') : _t('Copy', 'Copia')),
              ),
          ]),
          Text(_t('If the technician asks for it, tell them this code.', 'Se il tecnico te lo chiede, comunicagli questo codice.'), style: const TextStyle(fontSize: 12)),
          if (info?['device_name'] != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_t('PC name', 'Nome del PC')}: ${info!['device_name']}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
      ),
    ]));
  }
}

// ---------------------------------------------------------------- 2. remote control
class _RemotePage extends StatefulWidget {
  final Map<String, dynamic>? st;
  final Widget remote;
  const _RemotePage({required this.st, required this.remote});
  @override
  State<_RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<_RemotePage> {
  String? connecting, connectMsg;

  Future<void> _connect(Map<String, dynamic> t, String app) async {
    setState(() { connecting = '${t['id']}:$app'; connectMsg = _t('Connecting to ${t['name']}: setting a new password on it…', 'Connessione a ${t['name']}: imposto una nuova password…'); });
    final err = await hbConnect((t['id'] as num).toInt(), app);
    if (!mounted) return;
    setState(() {
      connecting = null;
      connectMsg = err == null ? _t('Opening ${_names[app]} on ${t['name']}.', 'Apro ${_names[app]} su ${t['name']}.') : _t('Cannot connect to ${t['name']}: $err', 'Impossibile connettersi a ${t['name']}: $err');
    });
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.st?['info']?['targets'];
    return Column(children: [
      if (targets is List) // technician PC: the devices managed by HelperBee
        ExpansionTile(
          leading: const Icon(Icons.devices_other, color: hbRed),
          title: Text(_t('HelperBee devices (${targets.length})', 'Dispositivi HelperBee (${targets.length})'), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: connectMsg != null ? Text(connectMsg!, style: const TextStyle(fontSize: 12)) : null,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                if (targets.isEmpty) Text(_t('No devices', 'Nessun dispositivo'), style: const TextStyle(color: Colors.grey)),
                for (final t in targets.cast<Map<String, dynamic>>())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(Icons.circle, size: 9, color: t['online'] == true ? Colors.green : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${t['name']}${t['group'] != null ? '  ·  ${t['group']}' : ''}', overflow: TextOverflow.ellipsis)),
                      for (final app in ((t['apps'] as List?) ?? const []).cast<String>())
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: OutlinedButton(
                            onPressed: connecting != null ? null : () => _connect(t, app),
                            child: connecting == '${t['id']}:$app'
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_names[app] ?? app),
                          ),
                        ),
                    ]),
                  ),
              ]),
            ),
          ],
        ),
      Expanded(child: widget.remote),
    ]);
  }
}

// ---------------------------------------------------------------- 3. settings
class _SettingsPage extends StatefulWidget {
  final Map<String, dynamic>? st;
  final Future<void> Function() reload;
  final VoidCallback? onNetworkSettings;
  const _SettingsPage({required this.st, required this.reload, this.onNetworkSettings});
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final server = TextEditingController();
  bool edited = false;
  String? msg;
  bool msgOk = false;

  @override
  void dispose() {
    server.dispose();
    super.dispose();
  }

  String get _agentExe => '${Platform.environment['ProgramFiles'] ?? r'C:\Program Files'}\\HelperBee\\helperbee-agent.exe';

  /// The same checks as the agent (http/https, a host, no spaces); the agent checks again, tries the URL and
  /// keeps the old one as fallback.
  String? _validate(String v) {
    final u = Uri.tryParse(v);
    if (v.isEmpty || u == null || !(u.scheme == 'https' || u.scheme == 'http') || u.host.isEmpty || v.contains(' ')) {
      return _t('Write the full address, e.g. https://helperbee.example.com or https://192.168.1.10:8080',
          "Scrivi l'indirizzo completo, es. https://helperbee.esempio.it oppure https://192.168.1.10:8080");
    }
    if (u.hasPort && (u.port < 1 || u.port > 65535)) return _t('The port must be between 1 and 65535.', 'La porta deve essere tra 1 e 65535.');
    return null;
  }

  Future<void> _save() async {
    final v = server.text.trim().replaceAll(RegExp(r'/+$'), '');
    final err = _validate(v);
    if (err != null) {
      setState(() { msg = err; msgOk = false; });
      return;
    }
    if (!File(_agentExe).existsSync()) {
      setState(() { msg = _t('The HelperBee agent is not installed on this PC.', "L'agent HelperBee non è installato su questo PC."); msgOk = false; });
      return;
    }
    try {
      await Process.start(_agentExe, ['set-server', '--server', v], mode: ProcessStartMode.detached);
      setState(() {
        msgOk = true;
        edited = false;
        msg = _t('Confirm the Windows prompt (administrator). HelperBee tries the new address first and shows the result in a window.',
            "Conferma la richiesta di Windows (amministratore). HelperBee prova prima il nuovo indirizzo e mostra l'esito in una finestra.");
      });
    } catch (e) {
      setState(() { msg = '$e'; msgOk = false; });
    }
    Timer(const Duration(seconds: 15), () => widget.reload());
  }

  Widget _row(String k, String v, {bool mono = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: TextStyle(fontSize: 13, fontFamily: mono ? 'monospace' : null))),
        ]),
      );

  Widget _section(String title, List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(.3)), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.st;
    final cur = '${s?['server'] ?? ''}';
    if (!edited && server.text != cur) server.text = cur;
    final rd = (s?['anydesk']?['apps']?['rustdesk']) as Map<String, dynamic>?;
    final ex = (rd?['extra'] as Map?) ?? const {};
    final key = '${ex['key'] ?? ''}';
    final connected = s?['connected'] == true;
    return _centered(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(_t('HelperBee server', 'Server HelperBee'), [
        _row(_t('Status', 'Stato'), s == null
            ? _t('HelperBee agent not running', 'Agent HelperBee non attivo')
            : connected
                ? _t('connected · last contact ${_ago(s['last_ok'])} ago', 'connesso · ultimo contatto ${_ago(s['last_ok'])} fa')
                : '${_t('unreachable', 'non raggiungibile')}${s['last_error'] != null ? ' (${s['last_error']})' : ''}'),
        const SizedBox(height: 8),
        TextField(
          controller: server,
          onChanged: (_) => edited = true,
          decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, labelText: _t('Server address (with port, if any)', 'Indirizzo del server (con la porta, se serve)')),
        ),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: hbRed, foregroundColor: Colors.white),
            onPressed: s == null ? null : _save,
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: Text(_t('Check and save', 'Verifica e salva')),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: () => setState(() { edited = false; msg = null; server.text = cur; }), child: Text(_t('Undo', 'Annulla'))),
        ]),
        if (msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg!, style: TextStyle(color: msgOk ? null : hbRed))),
        const SizedBox(height: 6),
        Text(
            _t('Needs a Windows administrator. The new address is tried before it is used; if it stops answering, HelperBee goes back to the previous one within 3 minutes.',
                "Serve un amministratore di Windows. Il nuovo indirizzo viene provato prima di usarlo; se poi non risponde, HelperBee torna a quello precedente entro 3 minuti."),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      _section(_t('Remote connection server (RustDesk)', 'Server per le connessioni remote (RustDesk)'), [
        _row(_t('ID server', 'Server ID'), '${ex['server'] ?? ''}'),
        _row(_t('Relay server', 'Server relay'), '${ex['relay'] ?? ''}'),
        _row(_t('Key', 'Chiave'), key.length > 16 ? '${key.substring(0, 8)}…${key.substring(key.length - 6)}' : key, mono: true),
        _row(_t('Code of this PC', 'Codice di questo PC'), rd?['id'] != null ? _fmtId('${rd!['id']}') : '', mono: true),
        const SizedBox(height: 6),
        Text(
            _t('Set for every PC by the HelperBee server (HelperBee → Settings → RustDesk server, with ports as host:port) and corrected automatically within a minute. If these values are wrong, fix the HelperBee server address above first.',
                "Impostati per tutti i PC dal server HelperBee (HelperBee → Impostazioni → Server RustDesk, porte come host:porta) e corretti da soli entro un minuto. Se questi valori sono sbagliati, correggi prima l'indirizzo del server HelperBee qui sopra."),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (widget.onNetworkSettings != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(onPressed: widget.onNetworkSettings, icon: const Icon(Icons.lan_outlined, size: 18), label: Text(_t('Advanced network settings', 'Impostazioni di rete avanzate'))),
          ),
      ]),
      _section(_t('About', 'Informazioni'), [
        _row(_t('HelperBee agent', 'Agent HelperBee'), '${s?['agent_version'] ?? ''}'),
        _row('HelperBee Remote', '${rd?['version'] ?? ''}'),
        _row(_t('PC name', 'Nome del PC'), '${s?['info']?['device_name'] ?? ''}'),
      ]),
    ]));
  }
}
