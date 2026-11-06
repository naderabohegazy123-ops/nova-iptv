import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/xtream_account.dart';
import '../services/m3u_parser.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _playlist = TextEditingController();

  List<Channel> _channels = [];
  String _section = 'Live TV';
  String _filter = 'All';
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _playlist.dispose();
    super.dispose();
  }

  Future<void> _addXtream() async {
    _server.clear(); _username.clear(); _password.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Xtream Codes'),
        content: SizedBox(width: 420, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _server, decoration: const InputDecoration(labelText: 'Server URL', hintText: 'https://provider.example:8080')),
            TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Connect')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final account = XtreamAccount(
        server: _server.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
      );
      final service = XtreamService();
      await service.authenticate(account);
      final rows = await service.liveStreams(account);
      final parsed = rows.map((e) => Channel(
        name: (e['name'] ?? 'Channel').toString(),
        url: '${account.server.replaceAll(RegExp(r'/+$'), '')}/live/${account.username}/${account.password}/${e['stream_id']}',
        logo: e['stream_icon']?.toString(),
        group: e['category_name']?.toString() ?? 'Live TV',
        tvgId: e['epg_channel_id']?.toString(),
      )).toList();
      service.close();
      if (mounted) setState(() { _channels = parsed; _section = 'Live TV'; });
      _notice('Connected. Loaded ${parsed.length} live channels.');
    } catch (e) {
      _notice('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addM3u() async {
    _playlist.clear();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add M3U playlist'),
        content: SizedBox(width: 440, child: TextField(
          controller: _playlist, minLines: 3, maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Playlist URL or pasted M3U content',
            hintText: 'https://.../playlist.m3u or #EXTM3U',
            border: OutlineInputBorder(),
          ),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _playlist.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    setState(() => _busy = true);
    try {
      final content = value.startsWith('#EXTM3U')
          ? value
          : (await http.get(Uri.parse(value)).timeout(const Duration(seconds: 30))).body;
      final parsed = M3uParser.parse(content);
      if (mounted) setState(() { _channels = parsed; _section = 'Live TV'; });
      _notice('Loaded ${parsed.length} playlist entries.');
    } catch (e) {
      _notice('Could not load playlist: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final groups = _channels.map((c) => c.group).toSet().toList()..sort();
    final filtered = _channels.where((c) {
      final q = _search.text.toLowerCase();
      return (_filter == 'All' || c.group == _filter) &&
          (q.isEmpty || c.name.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      body: Row(children: [
        Container(
          width: 218,
          color: const Color(0xFF0D1524),
          padding: const EdgeInsets.fromLTRB(18, 28, 12, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.play_circle_fill, color: Color(0xFF40D9C4), size: 30),
              SizedBox(width: 9),
              Text('NOVA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ]),
            const Text('IPTV PLAYER', style: TextStyle(color: Colors.white38, letterSpacing: 2, fontSize: 10)),
            const SizedBox(height: 36),
            for (final item in [
              ('Live TV', Icons.live_tv), ('Movies', Icons.movie_outlined),
              ('Series', Icons.video_library_outlined), ('Favorites', Icons.star_border),
              ('Recently played', Icons.history), ('Settings', Icons.settings_outlined),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: ListTile(
                  dense: true, selected: _section == item.$1,
                  selectedTileColor: const Color(0xFF19333A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: Icon(item.$2, size: 19),
                  title: Text(item.$1, style: const TextStyle(fontSize: 13)),
                  onTap: () => setState(() => _section = item.$1),
                ),
              ),
            const Spacer(),
            const Text('NOVA IPTV  •  v0.2', style: TextStyle(color: Colors.white30, fontSize: 10)),
          ]),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 25, 28, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_section, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
              const Spacer(),
              OutlinedButton.icon(onPressed: _addM3u, icon: const Icon(Icons.link), label: const Text('Add M3U')),
              const SizedBox(width: 9),
              FilledButton.icon(onPressed: _addXtream, icon: const Icon(Icons.add), label: const Text('Add Xtream')),
            ]),
            const SizedBox(height: 22),
            if (_section == 'Live TV') ...[
              Row(children: [
                SizedBox(width: 310, child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search channels...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                )),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filter,
                  items: ['All', ...groups].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _filter = v ?? 'All'),
                ),
                const Spacer(),
                Text('${filtered.length} channels', style: const TextStyle(color: Colors.white54)),
              ]),
              const SizedBox(height: 18),
              Expanded(child: _busy
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                  ? _emptyState()
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 245, mainAxisExtent: 112,
                        crossAxisSpacing: 13, mainAxisSpacing: 13,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return Card(
                          color: const Color(0xFF121D2E),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onDoubleTap: () => _play(c),
                            onTap: () => _play(c),
                            child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: const Color(0xFF20313F), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.live_tv, color: Color(0xFF40D9C4)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 5),
                                  Text(c.group, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              )),
                            ])),
                          ),
                        );
                      },
                    )),
            ] else
              Expanded(child: Center(child: Text(
                _section == 'Movies' || _section == 'Series'
                  ? 'Connect a provider to load this library in the next milestone.'
                  : 'This section will be enabled in the next milestone.',
                style: const TextStyle(color: Colors.white54),
              ))),
          ]),
        )),
      ]),
    );
  }

  Widget _emptyState() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.live_tv, size: 66, color: Color(0xFF40D9C4)),
      const SizedBox(height: 16),
      const Text('Your screen. Your channels.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 7),
      const Text('Add your own M3U playlist or Xtream Codes subscription.', style: TextStyle(color: Colors.white54)),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _addXtream, icon: const Icon(Icons.add), label: const Text('Connect subscription')),
    ],
  ));

  void _play(Channel channel) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)));
  }
}
