
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/xtream_account.dart';
import '../services/account_storage.dart';
import '../services/library_storage.dart';
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

  final _accountStorage = AccountStorage();
  final _libraryStorage = LibraryStorage();

  XtreamAccount? _account;

  List<Channel> _channels = [];
  List<Channel> _movies = [];
  List<dynamic> _series = [];

  List<String> _favorites = [];
  List<String> _history = [];

  String _section = 'Live TV';
  String _filter = 'All';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _favorites = await _libraryStorage.getFavorites();
    _history = await _libraryStorage.getHistory();

    final saved = await _accountStorage.read();

    if (saved != null) {
      _account = saved;
      _server.text = saved.server;
      _username.text = saved.username;
      await _connectXtream(saved, saveAccount: false);
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _playlist.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _streamUrl(
    XtreamAccount account,
    String type,
    String id,
    String extension,
  ) {
    final server = account.normalizedServer;
    final username = Uri.encodeComponent(account.username);
    final password = Uri.encodeComponent(account.password);

    return '$server/$type/$username/$password/$id.$extension';
  }

  Future<void> _connectXtream(
    XtreamAccount account, {
    bool saveAccount = true,
  }) async {
    setState(() => _busy = true);

    final service = XtreamService();

    try {
      await service.authenticate(account);

      final liveRows = await service.liveStreams(account);
      final categories = await service.liveCategories(account);

      final categoryNames = {
        for (final c in categories)
          c['category_id'].toString():
              c['category_name']?.toString() ?? 'Other'
      };

      final parsed = liveRows.map((e) {
        final id = e['stream_id'].toString();
        final extension =
            (e['container_extension'] ?? 'ts')
                .toString()
                .replaceFirst('.', '');

        final categoryId = e['category_id']?.toString();

        return Channel(
          id: id,
          categoryId: categoryId,
          extension: extension,
          contentType: 'live',
          name: (e['name'] ?? 'Channel').toString(),
          url: _streamUrl(account, 'live', id, extension),
          logo: e['stream_icon']?.toString(),
          group: categoryNames[categoryId] ??
              e['category_name']?.toString() ??
              'Other',
          tvgId: e['epg_channel_id']?.toString(),
        );
      }).toList();

      if (saveAccount) {
        await _accountStorage.save(account);
      }

      _account = account;
      _channels = parsed;
      _movies = [];
      _series = [];
      _filter = 'All';

      if (mounted) {
        setState(() {
          _section = 'Live TV';
          _busy = false;
        });
      }

      _notice('Connected. Loaded ${parsed.length} live channels.');
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _notice('Connection failed. Check your subscription and try again.');
    } finally {
      service.close();
    }
  }

  Future<void> _addXtream() async {
    _server.clear();
    _username.clear();
    _password.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Xtream Codes'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _server,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'server.example:8080',
                ),
              ),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final account = XtreamAccount(
      server: _server.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
    );

    await _connectXtream(account);
  }

  Future<void> _loadMovies() async {
    if (_account == null || _movies.isNotEmpty) return;

    setState(() => _busy = true);

    final service = XtreamService();

    try {
      final categories = await service.vodCategories(_account!);
      final rows = await service.vodStreams(_account!);

      final categoryNames = {
        for (final c in categories)
          c['category_id'].toString():
              c['category_name']?.toString() ?? 'Other'
      };

      _movies = rows.map((e) {
        final id = e['stream_id'].toString();
        final extension =
            (e['container_extension'] ?? 'mp4')
                .toString()
                .replaceFirst('.', '');
        final categoryId = e['category_id']?.toString();

        return Channel(
          id: id,
          categoryId: categoryId,
          extension: extension,
          contentType: 'movie',
          name: (e['name'] ?? 'Movie').toString(),
          url: _streamUrl(_account!, 'movie', id, extension),
          logo: e['stream_icon']?.toString(),
          group: categoryNames[categoryId] ?? 'Other',
        );
      }).toList();

      if (mounted) setState(() => _busy = false);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _notice('Could not load movies.');
    } finally {
      service.close();
    }
  }

  Future<void> _loadSeries() async {
    if (_account == null || _series.isNotEmpty) return;

    setState(() => _busy = true);

    final service = XtreamService();

    try {
      _series = await service.series(_account!);

      if (mounted) setState(() => _busy = false);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _notice('Could not load series.');
    } finally {
      service.close();
    }
  }

  Future<void> _openSeries(dynamic item) async {
    if (_account == null) return;

    final service = XtreamService();

    try {
      final details = await service.seriesInfo(
        _account!,
        item['series_id'].toString(),
      );

      final episodes = details['episodes'];
      final List<dynamic> allEpisodes = [];

      if (episodes is Map) {
        for (final season in episodes.values) {
          if (season is List) allEpisodes.addAll(season);
        }
      } else if (episodes is List) {
        allEpisodes.addAll(episodes);
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item['name']?.toString() ?? 'Series'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: allEpisodes.isEmpty
                ? const Center(child: Text('No episodes available.'))
                : ListView.builder(
                    itemCount: allEpisodes.length,
                    itemBuilder: (context, index) {
                      final episode = allEpisodes[index];
                      final id =
                          (episode['id'] ?? episode['episode_id']).toString();
                      final extension =
                          (episode['container_extension'] ?? 'mp4')
                              .toString()
                              .replaceFirst('.', '');

                      final channel = Channel(
                        id: id,
                        extension: extension,
                        contentType: 'episode',
                        name: (episode['title'] ??
                                'Episode ${index + 1}')
                            .toString(),
                        url: _streamUrl(
                          _account!,
                          'series',
                          id,
                          extension,
                        ),
                        group: item['name']?.toString() ?? 'Series',
                      );

                      return ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(channel.name),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _play(channel);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      _notice('Could not load series episodes.');
    } finally {
      service.close();
    }
  }

  Future<void> _addM3u() async {
    _playlist.clear();

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add M3U playlist'),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: _playlist,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Playlist URL or pasted M3U content',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _playlist.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty) return;

    setState(() => _busy = true);

    try {
      final content = value.startsWith('#EXTM3U')
          ? value
          : (await http.get(Uri.parse(value))
                  .timeout(const Duration(seconds: 30)))
              .body;

      final parsed = M3uParser.parse(content);

      if (mounted) {
        setState(() {
          _channels = parsed;
          _movies = [];
          _series = [];
          _account = null;
          _section = 'Live TV';
          _filter = 'All';
          _busy = false;
        });
      }

      _notice('Loaded ${parsed.length} playlist entries.');
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _notice('Could not load playlist.');
    }
  }

  Future<void> _toggleFavorite(Channel channel) async {
    final key = channel.uniqueKey;

    setState(() {
      if (_favorites.contains(key)) {
        _favorites.remove(key);
      } else {
        _favorites.add(key);
      }
    });

    await _libraryStorage.saveFavorites(_favorites);
  }

  Future<void> _play(
    Channel channel, {
    List<Channel>? queue,
    int index = 0,
  }) async {
    final key = channel.uniqueKey;

    _history.remove(key);
    _history.insert(0, key);

    if (_history.length > 100) {
      _history = _history.take(100).toList();
    }

    await _libraryStorage.saveHistory(_history);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: channel,
          playlist: queue ?? [channel],
          initialIndex: index,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openSection(String section) async {
    setState(() {
      _section = section;
      _filter = 'All';
    });

    if (section == 'Movies') await _loadMovies();
    if (section == 'Series') await _loadSeries();
  }

  Future<void> _settings() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Text(
          _account == null
              ? 'No Xtream subscription is saved.'
              : 'An Xtream subscription is saved on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          if (_account != null)
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove subscription'),
            ),
        ],
      ),
    );

    if (remove == true) {
      await _accountStorage.delete();

      setState(() {
        _account = null;
        _channels = [];
        _movies = [];
        _series = [];
        _section = 'Live TV';
      });

      _notice('Saved subscription removed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItems = switch (_section) {
      'Movies' => _movies,
      'Favorites' => [
          ..._channels,
          ..._movies,
        ].where((c) => _favorites.contains(c.uniqueKey)).toList(),
      'Recently played' => [
          ..._channels,
          ..._movies,
        ].where((c) => _history.contains(c.uniqueKey)).toList()
          ..sort((a, b) => _history.indexOf(a.uniqueKey)
              .compareTo(_history.indexOf(b.uniqueKey))),
      _ => _channels,
    };

    final groups = currentItems.map((c) => c.group).toSet().toList()
      ..sort();

    final filtered = currentItems.where((c) {
      final q = _search.text.toLowerCase();

      return (_filter == 'All' || c.group == _filter) &&
          (q.isEmpty || c.name.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 218,
            color: const Color(0xFF0D1524),
            padding: const EdgeInsets.fromLTRB(18, 28, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.play_circle_fill,
                        color: Color(0xFF40D9C4), size: 30),
                    SizedBox(width: 9),
                    Text(
                      'NOVA',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'IPTV PLAYER',
                  style: TextStyle(
                    color: Colors.white38,
                    letterSpacing: 2,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 36),
                for (final item in [
                  ('Live TV', Icons.live_tv),
                  ('Movies', Icons.movie_outlined),
                  ('Series', Icons.video_library_outlined),
                  ('Favorites', Icons.star_border),
                  ('Recently played', Icons.history),
                  ('Settings', Icons.settings_outlined),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: ListTile(
                      dense: true,
                      selected: _section == item.$1,
                      selectedTileColor: const Color(0xFF19333A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(item.$2, size: 19),
                      title: Text(
                        item.$1,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        if (item.$1 == 'Settings') {
                          _settings();
                        } else {
                          _openSection(item.$1);
                        }
                      },
                    ),
                  ),
                const Spacer(),
                const Text(
                  'NOVA IPTV • v0.3',
                  style: TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 25, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _section,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _addM3u,
                        icon: const Icon(Icons.link),
                        label: const Text('Add M3U'),
                      ),
                      const SizedBox(width: 9),
                      FilledButton.icon(
                        onPressed: _addXtream,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Xtream'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (_section != 'Series' && _section != 'Settings') ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 310,
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _filter,
                          items: ['All', ...groups]
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _filter = v ?? 'All'),
                        ),
                        const Spacer(),
                        Text(
                          '${filtered.length} items',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  Expanded(
                    child: _busy
                        ? const Center(child: CircularProgressIndicator())
                        : _section == 'Series'
                            ? _buildSeries()
                            : filtered.isEmpty
                                ? _emptyState()
                                : _buildGrid(filtered),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Channel> items) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 245,
        mainAxisExtent: 125,
        crossAxisSpacing: 13,
        mainAxisSpacing: 13,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final channel = items[index];
        final favorite = _favorites.contains(channel.uniqueKey);

        return Card(
          color: const Color(0xFF121D2E),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _play(
                      channel,
                      queue: items,
                      index: index,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          channel.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip:
                          favorite ? 'Remove favorite' : 'Add favorite',
                      onPressed: () => _toggleFavorite(channel),
                      icon: Icon(
                        favorite ? Icons.star : Icons.star_border,
                        color: favorite
                            ? const Color(0xFF40D9C4)
                            : Colors.white54,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Play',
                      onPressed: () => _play(
                        channel,
                        queue: items,
                        index: index,
                      ),
                      icon: const Icon(Icons.play_arrow),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeries() {
    if (_series.isEmpty) return _emptyState();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 245,
        mainAxisExtent: 110,
        crossAxisSpacing: 13,
        mainAxisSpacing: 13,
      ),
      itemCount: _series.length,
      itemBuilder: (context, index) {
        final item = _series[index];

        return Card(
          color: const Color(0xFF121D2E),
          child: ListTile(
            leading: const Icon(
              Icons.video_library,
              color: Color(0xFF40D9C4),
            ),
            title: Text(
              item['name']?.toString() ?? 'Series',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text('Open episodes'),
            onTap: () => _openSeries(item),
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.live_tv,
            size: 66,
            color: Color(0xFF40D9C4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your screen. Your channels.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Add your own M3U playlist or Xtream Codes subscription.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _addXtream,
            icon: const Icon(Icons.add),
            label: const Text('Connect subscription'),
          ),
        ],
      ),
    );
  }
}
