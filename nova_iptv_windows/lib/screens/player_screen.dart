import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/channel.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.channel});

  final Channel channel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  StreamSubscription<String>? _errorSubscription;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _player = Player();
    _controller = VideoController(_player);

    _errorSubscription = _player.stream.error.listen((message) {
      if (!mounted) return;

      setState(() {
        _error = message;
        _loading = false;
      });
    });

    _start();
  }

  Future<void> _start() async {
    try {
      await _player.open(Media(widget.channel.url));

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.channel.name),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Playback error\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Video(
                    controller: _controller,
                    controls: MaterialDesktopVideoControls,
                  ),

                  if (_loading)
                    const CircularProgressIndicator(
                      color: Color(0xFF40D9C4),
                    ),

                  StreamBuilder<bool>(
                    stream: _player.stream.buffering,
                    builder: (context, snapshot) {
                      if (snapshot.data != true || _error != null) {
                        return const SizedBox.shrink();
                      }

                      return const CircularProgressIndicator(
                        color: Color(0xFF40D9C4),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
