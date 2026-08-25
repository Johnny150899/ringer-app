import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/config/network_policy.dart';

class InstagramVideoScreen extends StatefulWidget {
  const InstagramVideoScreen({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  State<InstagramVideoScreen> createState() => _InstagramVideoScreenState();
}

class _InstagramVideoScreenState extends State<InstagramVideoScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initialization = _controller
        .initialize()
        .then((_) {
          _controller.play();
          if (mounted) setState(() {});
        })
        .timeout(NetworkPolicy.mediaTimeout);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
    }
    setState(() {});
  }

  void _toggleSound() {
    _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError || !_controller.value.isInitialized) {
            return const _VideoError();
          }
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final value = _controller.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: _togglePlayback,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                  if (!value.isPlaying)
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlayback,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            color: Color(0xB3061E39),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  if (value.isBuffering)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              color: Colors.white,
                              icon: const Icon(Icons.close_rounded),
                            ),
                            const Text(
                              'Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.navy, Color(0x99061E39)],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlayback,
                              color: Colors.white,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            Expanded(
                              child: VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                colors: const VideoProgressColors(
                                  playedColor: AppColors.red,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_duration(value.position)} / ${_duration(value.duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleSound,
                              color: Colors.white,
                              icon: Icon(
                                value.volume == 0
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
          SizedBox(height: 12),
          Text(
            'Das Video konnte nicht geladen werden.',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

Future<void> showInstagramVideo(
  BuildContext context, {
  required String videoUrl,
}) async {
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  try {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => InstagramVideoScreen(videoUrl: videoUrl),
      ),
    );
  } finally {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
}
