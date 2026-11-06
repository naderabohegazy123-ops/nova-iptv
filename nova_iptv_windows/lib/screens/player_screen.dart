import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.channel});
  final Channel channel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
      _controller = c;
      await c.initialize();
      await c.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.channel.name), backgroundColor: Colors.black),
      body: Center(
        child: _error != null
          ? Padding(padding: const EdgeInsets.all(24), child: Text('Playback error\n$_error', textAlign: TextAlign.center))
          : c == null || !c.value.isInitialized
            ? const CircularProgressIndicator()
            : AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  VideoPlayer(c),
                  VideoProgressIndicator(c, allowScrubbing: true),
                  Positioned(bottom: 24, child: IconButton.filled(
                    onPressed: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
                    icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
                  )),
                ]),
              ),
      ),
    );
  }
}
