
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/xtream_account.dart';
import '../services/xtream_service.dart';

class MovieDetailsScreen extends StatefulWidget {
  const MovieDetailsScreen({
    super.key,
    required this.account,
    required this.channel,
    required this.onPlay,
  });

  final XtreamAccount account;
  final Channel channel;
  final VoidCallback onPlay;

  @override
  State<MovieDetailsScreen> createState() =>
      _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final XtreamService _service = XtreamService();

  Map<String, dynamic> _info = {};
  bool _loading = true;
  String? _error;

  static const Color _background = Color(0xFF080D17);
  static const Color _card = Color(0xFF111A2A);
  static const Color _mint = Color(0xFF40D9C4);
  static const Color _muted = Color(0xFF9AA8BC);

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final id = widget.channel.id;

    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Movie ID is not available.';
      });
      return;
    }

    try {
      final result = await _service.vodInfo(
        widget.account,
        id,
      );

      if (!mounted) return;

      setState(() {
        _info = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load additional movie details.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _movieInfo {
    final value = _info['info'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  Map<String, dynamic> get _movieData {
    final value = _info['movie_data'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String? _value(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      final result = value.toString().trim();

      if (result.isNotEmpty &&
          result.toLowerCase() != 'null' &&
          result != '0') {
        return result;
      }
    }

    return null;
  }

  String? get _poster => _value([
        _movieInfo['movie_image'],
        widget.channel.logo,
      ]);

  String? get _name => _value([
        _movieInfo['name'],
        _movieData['name'],
        widget.channel.name,
      ]);

  String? get _year => _value([
        _movieInfo['releasedate'],
        _movieInfo['release_date'],
        _movieInfo['year'],
        widget.channel.year,
      ]);

  String? get _rating => _value([
        _movieInfo['rating'],
        widget.channel.rating,
      ]);

  String? get _plot => _value([
        _movieInfo['plot'],
        _movieInfo['description'],
        widget.channel.plot,
      ]);

  String? get _genre => _value([
        _movieInfo['genre'],
        widget.channel.genre,
      ]);

  String? get _duration => _value([
        _movieInfo['duration'],
        widget.channel.duration,
      ]);

  String? get _director => _value([
        _movieInfo['director'],
        widget.channel.director,
      ]);

  String? get _cast => _value([
        _movieInfo['cast'],
        widget.channel.cast,
      ]);

  List<String> get _backdrops {
    final value = _movieInfo['backdrop_path'];

    if (value is List) {
      return value
          .map((item) {
            if (item is Map) {
              return item['url']?.toString() ?? '';
            }

            return item.toString();
          })
          .where((item) => item.startsWith('http'))
          .toList();
    }

    if (value is String && value.startsWith('http')) {
      return [value];
    }

    final fallback = widget.channel.backdrop;

    if (fallback != null && fallback.startsWith('http')) {
      return [fallback];
    }

    return [];
  }

  Widget _posterWidget() {
    final poster = _poster;

    if (poster == null || !poster.startsWith('http')) {
      return _posterFallback();
    }

    return Image.network(
      poster,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _posterFallback(),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: _card,
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          size: 65,
          color: _muted,
        ),
      ),
    );
  }

  Widget _tag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _mint),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String title, String? value) {
    if (value == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backdrops = _backdrops;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Movie Details'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _mint,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (backdrops.isNotEmpty)
                    SizedBox(
                      height: 230,
                      width: double.infinity,
                      child: Image.network(
                        backdrops.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 150,
                            height: 220,
                            child: _posterWidget(),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name ?? 'Unknown Movie',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_year != null)
                                    _tag(
                                      _year!,
                                      Icons.calendar_today,
                                    ),
                                  if (_rating != null)
                                    _tag(
                                      _rating!,
                                      Icons.star,
                                    ),
                                  if (_duration != null)
                                    _tag(
                                      _duration!,
                                      Icons.schedule,
                                    ),
                                ],
                              ),
                              if (_genre != null) ...[
                                const SizedBox(height: 18),
                                Text(
                                  _genre!,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: widget.onPlay,
                                  icon: const Icon(
                                    Icons.play_arrow,
                                  ),
                                  label: const Text('Play Movie'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _mint,
                                    foregroundColor: _background,
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 22,
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
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_plot != null) ...[
                          _sectionTitle('Overview'),
                          Text(
                            _plot!,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 14,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        if (_director != null || _cast != null) ...[
                          _sectionTitle('Movie Information'),
                          _detail('Director', _director),
                          _detail('Cast', _cast),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
