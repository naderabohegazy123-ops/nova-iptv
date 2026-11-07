
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
  static const Color _background = Color(0xFF080D17);
  static const Color _sidebar = Color(0xFF0D1524);
  static const Color _card = Color(0xFF121D2E);
  static const Color _mint = Color(0xFF40D9C4);

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

  @override
  void dispose() {
    _search.dispose();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _playlist.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final favorites = await _libraryStorage.getFavorites();
      final history = await _libraryStorage.getHistory();
      final savedM3u = await _libraryStorage.getM3uChannels();

      if (!mounted) return;

      setState(() {
        _favorites = favorites;
        _history = history;
        _channels = savedM3u;
      });

      final saved = await _accountStorage.read();

      if (!mounted) return;

      if (saved != null) {
        _account = saved;
        _server.text = saved.server;
        _username.text = saved.username;

        await _connectXtream(saved, saveAccount: false);
      }
    } catch (_) {
      _notice('Could not restore saved data.');
    }
  }

  void _notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
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
    if (!mounted) return;

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

      final parsed = liveRows
          .where((e) => e['stream_id'] != null)
          .map((e) {
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

      if (!mounted) return;

      setState(() {
        _account = account;
        _channels = parsed;
        _movies = [];
        _series = [];
        _filter = 'All';
        _section = 'Live TV';
        _busy = false;
      });

      _notice('Connected. Loaded ${parsed.length} live channels.');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
      }

      _notice(
        'Connection failed. Check your subscription and try again.',
      );
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
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
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

    if (ok != true || !mounted) return;

    final account = XtreamAccount(
      server: _server.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
    );

    await _connectXtream(account);
  }

  Future<void> _loadMovies() async {
    final account = _account;

    if (account == null || _movies.isNotEmpty) return;

    setState(() => _busy = true);

    final service = XtreamService();

    try {
      final categories = await service.vodCategories(account);
      final rows = await service.vodStreams(account);

      final categoryNames = {
        for (final c in categories)
          c['category_id'].toString():
              c['category_name']?.toString() ?? 'Other'
      };

      final parsed = rows
          .where((e) => e['stream_id'] != null)
          .map((e) {
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
          url: _streamUrl(account, 'movie', id, extension),
          logo: e['stream_icon']?.toString(),
          group: categoryNames[categoryId] ?? 'Other',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _movies = parsed;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
      }

      _notice('Could not load movies.');
    } finally {
      service.close();
    }
  }

  Future<void> _loadSeries() async {
    final account = _account;

    if (account == null || _series.isNotEmpty) return;

    setState(() => _busy = true);

    final service = XtreamService();

    try {
      final result = await service.series(account);

      if (mounted) {
        setState(() {
          _series = result;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
      }

      _notice('Could not load series.');
    } finally {
      service.close();
    }
  }

  Future<void> _openSeries(dynamic item) async {
    final account = _account;

    if (account == null) return;

    final service = XtreamService();

    try {
      final details = await service.seriesInfo(
        account,
        item['series_id'].toString(),
      );

      final episodes = details['episodes'];
      final List<dynamic> allEpisodes = [];

      if (episodes is Map) {
        for (final season in episodes.values) {
          if (season is List) {
            allEpisodes.addAll(season);
          }
        }
      } else if (episodes is List) {
        allEpisodes.addAll(episodes);
      }

      if (!mounted) return;

      final episodeChannels = allEpisodes
          .where((e) =>
              e['id'] != null || e['episode_id'] != null)
          .map((episode) {
        final id =
            (episode['id'] ?? episode['episode_id']).toString();

        final extension =
            (episode['container_extension'] ?? 'mp4')
                .toString()
                .replaceFirst('.', '');

        return Channel(
          id: id,
          extension: extension,
          contentType: 'episode',
          name: (episode['title'] ?? 'Episode').toString(),
          url: _streamUrl(account, 'series', id, extension),
          group: item['name']?.toString() ?? 'Series',
        );
      }).toList();

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item['name']?.toString() ?? 'Series'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: episodeChannels.isEmpty
                ? const Center(
                    child: Text('No episodes available.'),
                  )
                : ListView.builder(
                    itemCount: episodeChannels.length,
                    itemBuilder: (context, index) {
                      final channel = episodeChannels[index];

                      return ListTile(
                        leading: const Icon(
                          Icons.play_circle_outline,
                        ),
                        title: Text(channel.name),
                        onTap: () {
                          Navigator.pop(dialogContext);

                          _play(
                            channel,
                            queue: episodeChannels,
                            index: index,
                          );
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
            onPressed: () {
              Navigator.pop(context, _playlist.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty || !mounted) return;

    setState(() => _busy = true);

    try {
      String content;

      if (value.startsWith('#EXTM3U')) {
        content = value;
      } else {
        final uri = Uri.tryParse(value);

        if (uri == null ||
            !uri.hasAuthority ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          throw const FormatException('Invalid playlist URL');
        }

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          throw Exception('Playlist request failed');
        }

        content = response.body;
      }

      final parsed = M3uParser.parse(content);

      if (parsed.isEmpty) {
        throw const FormatException('Empty playlist');
      }

      await _libraryStorage.saveM3uChannels(parsed);
      await _accountStorage.delete();

      if (!mounted) return;

      setState(() {
        _channels = parsed;
        _movies = [];
        _series = [];
        _account = null;
        _section = 'Live TV';
        _filter = 'All';
        _busy = false;
      });

      _notice('Loaded and saved ${parsed.length} playlist entries.');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
      }

      _notice(
        'Could not load playlist. Check the URL or content.',
      );
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

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openSection(String section) async {
    setState(() {
      _section = section;
      _filter = 'All';
      _search.clear();
    });

    if (section == 'Movies') {
      await _loadMovies();
    }

    if (section == 'Series') {
      await _loadSeries();
    }

    if ((section == 'Favorites' ||
            section == 'Recently played') &&
        _account != null) {
      await _loadMovies();
    }
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

      final savedM3u = await _libraryStorage.getM3uChannels();

      if (!mounted) return;

      setState(() {
        _account = null;
        _channels = savedM3u;
        _movies = [];
        _series = [];
        _section = 'Live TV';
        _filter = 'All';
      });

      _notice('Saved subscription removed.');
    }
  }

  List<Channel> _currentItems() {
    switch (_section) {
      case 'Movies':
        return _movies;

      case 'Favorites':
        return [
          ..._channels,
          ..._movies,
        ].where((c) => _favorites.contains(c.uniqueKey)).toList();

      case 'Recently played':
        final items = [
          ..._channels,
          ..._movies,
        ].where((c) => _history.contains(c.uniqueKey)).toList();

        items.sort(
          (a, b) => _history
              .indexOf(a.uniqueKey)
              .compareTo(_history.indexOf(b.uniqueKey)),
        );

        return items;

      default:
        return _channels;
    }
  }

  List<Channel> _filteredItems() {
    final items = _currentItems();
    final query = _search.text.toLowerCase();

    return items.where((channel) {
      final matchesGroup =
          _filter == 'All' || channel.group == _filter;

      final matchesSearch =
          query.isEmpty || channel.name.toLowerCase().contains(query);

      return matchesGroup && matchesSearch;
    }).toList();
  }

  List<String> _groups() {
    final groups = _currentItems()
        .map((channel) => channel.group)
        .toSet()
        .toList();

    groups.sort();

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems();
    final groups = _groups();

    return Scaffold(
      backgroundColor: _background,
      body: Row(
        children: [
          _buildMainSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _busy
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _mint,
                          ),
                        )
                      : _section == 'Series'
                          ? _buildSeries()
                          : _buildLibrary(
                              items,
                              groups,
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSidebar() {
    return Container(
      width: 215,
      color: _sidebar,
      padding: const EdgeInsets.fromLTRB(16, 28, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.play_circle_fill,
                color: _mint,
                size: 32,
              ),
              SizedBox(width: 9),
              Text(
                'NOVA',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Padding(
            padding: EdgeInsets.only(left: 41),
            child: Text(
              'IPTV PLAYER',
              style: TextStyle(
                color: Colors.white38,
                letterSpacing: 2,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(height: 38),
          _navItem('Live TV', Icons.live_tv),
          _navItem('Movies', Icons.movie_outlined),
          _navItem('Series', Icons.video_library_outlined),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 13, bottom: 9),
            child: Text(
              'MY LIBRARY',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          _navItem('Favorites', Icons.star_border),
          _navItem('Recently played', Icons.history),
          const Spacer(),
          _navItem('Settings', Icons.settings_outlined),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            'NOVA IPTV',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Windows Edition • v0.3',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String title, IconData icon) {
    final selected = _section == title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? const Color(0xFF19333A)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {
            if (title == 'Settings') {
              _settings();
            } else {
              _openSection(title);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? _mint : Colors.white60,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _mint,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 27),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Text(
            _section,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF19333A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _section == 'Series'
                  ? '${_series.length} series'
                  : '${_currentItems().length} items',
              style: const TextStyle(
                color: _mint,
                fontSize: 10,
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _addM3u,
            icon: const Icon(Icons.link, size: 17),
            label: const Text('Add M3U'),
          ),
          const SizedBox(width: 9),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _mint,
              foregroundColor: const Color(0xFF07131B),
            ),
            onPressed: _addXtream,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Add Xtream'),
          ),
        ],
      ),
    );
  }

  Widget _buildLibrary(
    List<Channel> items,
    List<String> groups,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 43,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search ${_section.toLowerCase()}...',
                      prefixIcon: const Icon(Icons.search, size: 19),
                      filled: true,
                      fillColor: _card,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Text(
                '${items.length} results',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategorySidebar(groups),
                const SizedBox(width: 20),
                Expanded(
                  child: items.isEmpty
                      ? _emptyState()
                      : _buildGrid(items),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySidebar(List<String> groups) {
    return Container(
      width: 175,
      decoration: BoxDecoration(
        color: _sidebar,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(9, 8, 8, 14),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _categoryItem('All', Icons.grid_view),
                for (final group in groups)
                  _categoryItem(
                    group,
                    Icons.folder_outlined,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryItem(String name, IconData icon) {
    final selected = _filter == name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? const Color(0xFF19333A)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => setState(() => _filter = name),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? _mint : Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white : Colors.white60,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<Channel> items) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 215,
        mainAxisExtent: 190,
        crossAxisSpacing: 13,
        mainAxisSpacing: 13,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final channel = items[index];
        final favorite = _favorites.contains(channel.uniqueKey);
        final isMovie = channel.contentType == 'movie';

        return Material(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _play(
              channel,
              queue: items,
              index: index,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: const Color(0xFF182438),
                        child: _buildArtwork(
                          channel.logo,
                          isMovie: isMovie,
                        ),
                      ),
                      if (!isMovie)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xFF40D9C4),
                                  size: 6,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        right: 5,
                        top: 4,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: favorite
                              ? 'Remove favorite'
                              : 'Add favorite',
                          onPressed: () => _toggleFavorite(channel),
                          icon: Icon(
                            favorite ? Icons.star : Icons.star_border,
                            color: favorite ? _mint : Colors.white70,
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white.withOpacity(0.85),
                          size: 35,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              channel.group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.play_arrow,
                        color: _mint,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtwork(
    String? url, {
    required bool isMovie,
  }) {
    if (url == null || url.trim().isEmpty) {
      return Center(
        child: Icon(
          isMovie ? Icons.movie_outlined : Icons.live_tv,
          size: 42,
          color: Colors.white24,
        ),
      );
    }

    return Image.network(
      url,
      fit: isMovie ? BoxFit.cover : BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            isMovie ? Icons.movie_outlined : Icons.live_tv,
            size: 42,
            color: Colors.white24,
          ),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _mint,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeries() {
    if (_series.isEmpty) return _emptyState();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate:
            const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 225,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: _series.length,
        itemBuilder: (context, index) {
          final item = _series[index];

          final cover = item['cover']?.toString();

          return Material(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openSeries(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: cover == null || cover.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFF182438),
                            child: Center(
                              child: Icon(
                                Icons.video_library,
                                size: 48,
                                color: Colors.white24,
                              ),
                            ),
                          )
                        : Image.network(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const ColoredBox(
                                color: Color(0xFF182438),
                                child: Center(
                                  child: Icon(
                                    Icons.video_library,
                                    size: 48,
                                    color: Colors.white24,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name']?.toString() ?? 'Series',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_outline,
                          color: _mint,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.live_tv,
            size: 65,
            color: _mint,
          ),
          const SizedBox(height: 17),
          const Text(
            'Your screen. Your channels.',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your own M3U playlist or Xtream Codes subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 19),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _mint,
              foregroundColor: const Color(0xFF07131B),
            ),
            onPressed: _addXtream,
            icon: const Icon(Icons.add),
            label: const Text('Connect subscription'),
          ),
        ],
      ),
    );
  }
}
