
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/channel.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.channel,
    this.playlist = const [],
    this.initialIndex = 0,
  });

  final Channel channel;
  final List<Channel> playlist;
  final int initialIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late int _currentIndex;

  String? _error;
  bool _loading = true;
  bool _fullscreen = false;

  Channel get _currentChannel {
    if (widget.playlist.isEmpty) return widget.channel;
    return widget.playlist[_currentIndex];
  }

  bool get _hasPrevious =>
      widget.playlist.isNotEmpty && _currentIndex > 0;

  bool get _hasNext =>
      widget.playlist.isNotEmpty &&
      _currentIndex < widget.playlist.length - 1;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.playlist.isEmpty
        ? 0
        : widget.initialIndex
            .clamp(0, widget.playlist.length - 1)
            .toInt();

    _player = Player();
    _controller = VideoController(_player);

    _player.stream.error.listen((error) {
      if (!mounted || error.isEmpty) return;

      setState(() {
        _error = 'Unable to play this content.';
        _loading = false;
      });
    });

    _start();
  }

  Future<void> _start() async {
    if (!mounted) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await _player.open(
        Media(_currentChannel.url),
        play: true,
      );

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to play this content.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _next() async {
    if (!_hasNext) return;

    setState(() => _currentIndex++);
    await _start();
  }

  Future<void> _previous() async {
    if (!_hasPrevious) return;

    setState(() => _currentIndex--);
    await _start();
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              title: Text(_currentChannel.name),
              backgroundColor: Colors.black,
            ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? _errorView()
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Video(controller: _controller),
                      ),
                      if (_loading)
                        const CircularProgressIndicator(
                          color: Color(0xFF40D9C4),
                        ),
                    ],
                  ),
          ),
          if (_error == null) _controls(),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Playback failed',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    return Container(
      color: const Color(0xFF101722),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration>(
            stream: _player.stream.position,
            initialData: Duration.zero,
            builder: (context, positionSnapshot) {
              final position =
                  positionSnapshot.data ?? Duration.zero;

              return StreamBuilder<Duration>(
                stream: _player.stream.duration,
                initialData: Duration.zero,
                builder: (context, durationSnapshot) {
                  final duration =
                      durationSnapshot.data ?? Duration.zero;

                  final max =
                      duration.inMilliseconds.toDouble();

                  final current = position.inMilliseconds
                      .toDouble()
                      .clamp(0.0, max > 0 ? max : 1.0)
                      .toDouble();

                  return Column(
                    children: [
                      Slider(
                        value: current,
                        min: 0,
                        max: max > 0 ? max : 1,
                        activeColor: const Color(0xFF40D9C4),
                        onChanged: max <= 0
                            ? null
                            : (value) {
                                _player.seek(
                                  Duration(
                                    milliseconds: value.toInt(),
                                  ),
                                );
                              },
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTime(position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _formatTime(duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: _hasPrevious ? _previous : null,
                icon: const Icon(Icons.skip_previous),
              ),
              StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: false,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;

                  return IconButton.filled(
                    iconSize: 30,
                    onPressed: () {
                      if (playing) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                    icon: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: _hasNext ? _next : null,
                icon: const Icon(Icons.skip_next),
              ),
              const Spacer(),
              const Icon(Icons.volume_up, size: 19),
              SizedBox(
                width: 110,
                child: StreamBuilder<double>(
                  stream: _player.stream.volume,
                  initialData: 100,
                  builder: (context, snapshot) {
                    final volume = (snapshot.data ?? 100)
                        .clamp(0.0, 100.0)
                        .toDouble();

                    return Slider(
                      value: volume,
                      min: 0,
                      max: 100,
                      activeColor: const Color(0xFF40D9C4),
                      onChanged: (value) {
                        _player.setVolume(value);
                      },
                    );
                  },
                ),
              ),
              IconButton(
                tooltip: _fullscreen
                    ? 'Exit fullscreen'
                    : 'Fullscreen',
                onPressed: () {
                  setState(() => _fullscreen = !_fullscreen);
                },
                icon: Icon(
                  _fullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
