
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
  static const Color _muted = Color(0xFF8995A8);

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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF202C3E),
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

    if (mounted) {
      setState(() => _busy = true);
    }

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

  // فتح تفاصيل الفيلم وتحميل بياناته من Xtream.
  Future<void> _openMovie(
    Channel movie, {
    required List<Channel> queue,
    required int index,
  }) async {
    final account = _account;

    if (account == null || movie.id == null) {
      _notice('Movie details are not available.');
      return;
    }

    final service = XtreamService();

    try {
      final detailsFuture = service.vodInfo(account, movie.id!);

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return FutureBuilder<Map<String, dynamic>>(
            future: detailsFuture,
            builder: (context, snapshot) {
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;

              final details = snapshot.data ?? {};
              final info = details['info'] is Map
                  ? Map<String, dynamic>.from(details['info'])
                  : <String, dynamic>{};

              final movieData = details['movie_data'] is Map
                  ? Map<String, dynamic>.from(details['movie_data'])
                  : <String, dynamic>{};

              final name = _firstValue([
                info['name'],
                movieData['name'],
                movie.name,
              ]);

              final plot = _firstValue([
                info['plot'],
                info['description'],
                movieData['plot'],
              ]);

              final genre = _firstValue([
                info['genre'],
                movieData['genre'],
              ]);

              final year = _firstValue([
                info['releasedate'],
                info['release_date'],
                info['year'],
                movieData['year'],
              ]);

              final rating = _firstValue([
                info['rating'],
                info['rating_5based'],
                movieData['rating'],
              ]);

              final duration = _firstValue([
                info['duration'],
                info['duration_secs'],
              ]);

              final director = _firstValue([
                info['director'],
                movieData['director'],
              ]);

              final cast = _firstValue([
                info['cast'],
                movieData['cast'],
              ]);

              final poster = _firstValue([
                info['movie_image'],
                info['cover'],
                movie.logo,
              ]);

              return Dialog(
                backgroundColor: _card,
                insetPadding: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SizedBox(
                  width: 760,
                  child: loading
                      ? const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _mint,
                            ),
                          ),
                        )
                      : _movieDetailsContent(
                          context: dialogContext,
                          movie: movie,
                          name: name,
                          poster: poster,
                          plot: plot,
                          genre: genre,
                          year: year,
                          rating: rating,
                          duration: duration,
                          director: director,
                          cast: cast,
                          hasError: snapshot.hasError,
                          onPlay: () {
                            Navigator.pop(dialogContext);
                            _play(
                              movie,
                              queue: queue,
                              index: index,
                            );
                          },
                        ),
                ),
              );
            },
          );
        },
      );
    } catch (_) {
      _notice('Could not load movie details.');
    } finally {
      service.close();
    }
  }

  String _firstValue(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty &&
          text.toLowerCase() != 'null' &&
          text != '0' &&
          text != '0.0') {
        return text;
      }
    }

    return '';
  }

  Widget _movieDetailsContent({
    required BuildContext context,
    required Channel movie,
    required String name,
    required String poster,
    required String plot,
    required String genre,
    required String year,
    required String rating,
    required String duration,
    required String director,
    required String cast,
    required bool hasError,
    required VoidCallback onPlay,
  }) {
    final validPoster = poster.startsWith('http://') ||
        poster.startsWith('https://');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
            ),
            child: SizedBox(
              height: 270,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (validPoster)
                    Image.network(
                      poster,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _moviePosterFallback(),
                    )
                  else
                    _moviePosterFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Colors.black.withValues(alpha: 0.65),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 20,
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    if (year.isNotEmpty)
                      _detailChip(Icons.calendar_today, year),
                    if (rating.isNotEmpty)
                      _detailChip(Icons.star_rounded, rating),
                    if (genre.isNotEmpty)
                      _detailChip(Icons.category_outlined, genre),
                    if (duration.isNotEmpty)
                      _detailChip(Icons.schedule, duration),
                  ],
                ),
                if (plot.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'OVERVIEW',
                    style: TextStyle(
                      color: _mint,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    plot,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
                if (director.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _detailText('Director', director),
                ],
                if (cast.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailText('Cast', cast),
                ],
                if (hasError) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Some movie information could not be loaded. '
                    'You can still try playing the movie.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onPlay,
                    style: FilledButton.styleFrom(
                      backgroundColor: _mint,
                      foregroundColor: const Color(0xFF07131B),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Play Movie',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A3D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _mint, size: 15),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _mint,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _moviePosterFallback() {
    return Container(
      color: const Color(0xFF1A293D),
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          color: _mint,
          size: 65,
        ),
      ),
    );
  }

  Future<void> _loadSeries() async {
    final account = _account;

    if (account == null || _series.isNotEmpty) return;

    if (mounted) {
      setState(() => _busy = true);
    }

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
          .where((e) => e['id'] != null || e['episode_id'] != null)
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
        return [..._channels, ..._movies]
            .where((c) => _favorites.contains(c.uniqueKey))
            .toList();

      case 'Recently played':
        final items = [..._channels, ..._movies]
            .where((c) => _history.contains(c.uniqueKey))
            .toList();

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

  List<Channel> _filteredItems(List<Channel> items) {
    final query = _search.text.trim().toLowerCase();

    return items.where((channel) {
      final matchesGroup =
          _filter == 'All' || channel.group == _filter;

      final matchesSearch =
          query.isEmpty || channel.name.toLowerCase().contains(query);

      return matchesGroup && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentItems = _currentItems();
    final filteredItems = _filteredItems(currentItems);

    final groups = currentItems.map((c) => c.group).toSet().toList()
      ..sort();

    return Scaffold(
      backgroundColor: _background,
      body: Row(
        children: [
          _buildMainSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 25, 28, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 25),
                  if (_section != 'Series') ...[
                    _buildSearchBar(filteredItems.length),
                    const SizedBox(height: 20),
                  ],
                  Expanded(
                    child: _busy
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _mint,
                            ),
                          )
                        : _section == 'Series'
                            ? _buildSeries()
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (currentItems.isNotEmpty)
                                    _buildCategorySidebar(groups),
                                  if (currentItems.isNotEmpty)
                                    const SizedBox(width: 20),
                                  Expanded(
                                    child: filteredItems.isEmpty
                                        ? _emptyState()
                                        : _section == 'Movies'
                                            ? _buildMovies(filteredItems)
                                            : _buildGrid(filteredItems),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSidebar() {
    final items = [
      ('Live TV', Icons.live_tv_outlined),
      ('Movies', Icons.movie_outlined),
      ('Series', Icons.video_library_outlined),
      ('Favorites', Icons.star_border_rounded),
      ('Recently played', Icons.history_rounded),
    ];

    return Container(
      width: 215,
      color: _sidebar,
      padding: const EdgeInsets.fromLTRB(17, 28, 13, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                color: _mint,
                size: 34,
              ),
              SizedBox(width: 9),
              Text(
                'NOVA',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 44, top: 1),
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
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              'LIBRARY',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final item in items)
            _navigationItem(item.$1, item.$2),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              'PREFERENCES',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _navigationItem(
            'Settings',
            Icons.settings_outlined,
            onTap: _settings,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF142438),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _mint,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'NOVA PLAYER',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _account != null
                      ? 'Xtream connected'
                      : _channels.isNotEmpty
                          ? 'M3U playlist loaded'
                          : 'No playlist connected',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Center(
            child: Text(
              'NOVA IPTV  •  v0.3',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigationItem(
    String title,
    IconData icon, {
    VoidCallback? onTap,
  }) {
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
          onTap: onTap ?? () => _openSection(title),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? _mint : _muted,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : _muted,
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const Spacer(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _section,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _section == 'Live TV'
                  ? 'Browse and watch your live channels'
                  : _section == 'Movies'
                      ? 'Your movie collection'
                      : _section == 'Series'
                          ? 'Explore your favorite series'
                          : _section == 'Favorites'
                              ? 'Your saved favorites'
                              : 'Continue watching',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _addM3u,
          icon: const Icon(Icons.link_rounded, size: 18),
          label: const Text('Add M3U'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Color(0xFF344258)),
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 17,
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _addXtream,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Add Xtream'),
          style: FilledButton.styleFrom(
            backgroundColor: _mint,
            foregroundColor: const Color(0xFF07131B),
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 17,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(int count) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search channels, movies...',
                hintStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _muted,
                  size: 20,
                ),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(
                          Icons.close,
                          size: 17,
                          color: _muted,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: _mint,
              ),
              const SizedBox(width: 8),
              Text(
                '$count items',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySidebar(List<String> groups) {
    final counts = <String, int>{};

    for (final channel in _currentItems()) {
      counts[channel.group] = (counts[channel.group] ?? 0) + 1;
    }

    return Container(
      width: 190,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: _sidebar,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(9, 5, 5, 15),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 1.3,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _categoryItem(
                  'All',
                  _currentItems().length,
                  Icons.apps_rounded,
                ),
                for (final group in groups)
                  _categoryItem(
                    group,
                    counts[group] ?? 0,
                    Icons.folder_outlined,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryItem(
    String title,
    int count,
    IconData icon,
  ) {
    final selected = _filter == title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? const Color(0xFF19333A)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _filter = title),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? _mint : _muted,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : _muted,
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? _mint : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // شبكة الأفلام: الضغط على الفيلم يفتح التفاصيل بدل التشغيل المباشر.
  Widget _buildMovies(List<Channel> items) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 10),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 330,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final movie = items[index];
        final favorite = _favorites.contains(movie.uniqueKey);

        return Material(
          color: _card,
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openMovie(
              movie,
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
                      if (movie.logo != null &&
                          movie.logo!.startsWith('http'))
                        Image.network(
                          movie.logo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _moviePosterFallback(),
                        )
                      else
                        _moviePosterFallback(),
                      Positioned(
                        top: 9,
                        right: 9,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.65),
                          ),
                          onPressed: () => _toggleFavorite(movie),
                          icon: Icon(
                            favorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: favorite ? _mint : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: _mint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF07131B),
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        movie.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: _mint,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'View details',
                            style: TextStyle(
                              color: _mint,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildGrid(List<Channel> items) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 10),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 118,
        crossAxisSpacing: 13,
        mainAxisSpacing: 13,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final channel = items[index];
        final favorite = _favorites.contains(channel.uniqueKey);

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
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  _channelLogo(channel.logo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          channel.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: favorite
                            ? 'Remove favorite'
                            : 'Add favorite',
                        onPressed: () => _toggleFavorite(channel),
                        icon: Icon(
                          favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 19,
                          color: favorite ? _mint : Colors.white38,
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _mint.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: _mint,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _channelLogo(String? logo) {
    final validLogo = logo != null &&
        logo.trim().isNotEmpty &&
        (logo.startsWith('http://') || logo.startsWith('https://'));

    return Container(
      width: 58,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF1A293D),
        borderRadius: BorderRadius.circular(9),
      ),
      clipBehavior: Clip.antiAlias,
      child: validLogo
          ? Image.network(
              logo,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _logoFallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _logoFallback();
              },
            )
          : _logoFallback(),
    );
  }

  Widget _logoFallback() {
    return const Center(
      child: Icon(
        Icons.live_tv_rounded,
        color: _mint,
        size: 27,
      ),
    );
  }

  Widget _buildSeries() {
    if (_series.isEmpty) return _emptyState();

    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisExtent: 285,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: _series.length,
      itemBuilder: (context, index) {
        final item = _series[index];
        final name = item['name']?.toString() ?? 'Series';
        final cover = item['cover']?.toString() ?? '';

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
                  child: cover.startsWith('http')
                      ? Image.network(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _seriesFallback(),
                        )
                      : _seriesFallback(),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 16,
                            color: _mint,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Open episodes',
                            style: TextStyle(
                              color: _mint,
                              fontSize: 10,
                            ),
                          ),
                        ],
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

  Widget _seriesFallback() {
    return Container(
      color: const Color(0xFF1A293D),
      child: const Center(
        child: Icon(
          Icons.video_library_outlined,
          color: _mint,
          size: 48,
        ),
      ),
    );
  }

  Widget _emptyState() {
    final noAccount = _account == null && _channels.isEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: _mint.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              size: 42,
              color: _mint,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            noAccount
                ? 'Welcome to NOVA'
                : 'Nothing to show here',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            noAccount
                ? 'Connect your subscription or add an M3U playlist.'
                : 'Try another category or search term.',
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (noAccount) ...[
            const SizedBox(height: 22),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _addXtream,
                  icon: const Icon(Icons.add),
                  label: const Text('Connect Xtream'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: const Color(0xFF07131B),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _addM3u,
                  icon: const Icon(Icons.link),
                  label: const Text('Add M3U'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
