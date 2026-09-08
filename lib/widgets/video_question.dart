import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class VideoQuestion extends StatefulWidget {
  final String? videoUrl;
  final String duration;
  final bool isPlaying;
  final VoidCallback onTogglePlay;

  const VideoQuestion({
    super.key,
    required this.videoUrl,
    required this.duration,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  State<VideoQuestion> createState() => _VideoQuestionState();
}

class _VideoQuestionState extends State<VideoQuestion> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final url = widget.videoUrl;
    if (url == null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.setLooping(true);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.isPlaying) controller.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(covariant VideoQuestion old) {
    super.didUpdateWidget(old);
    if (widget.videoUrl != old.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _failed = false;
      _initController();
    } else if (widget.isPlaying != old.isPlaying && _ready) {
      widget.isPlaying ? _controller!.play() : _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: AppColors.videoPlaceholder,
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            if (_ready)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            if (!_ready && !_failed && widget.videoUrl != null)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
                ),
              ),
            if (_failed)
              Center(
                child: Text(
                  'Video failed to load',
                  style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: Colors.white70),
                ),
              ),
            if (widget.videoUrl == null)
              Center(
                child: Text(
                  'No video attached yet',
                  style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: Colors.white70),
                ),
              ),
            Center(
              child: GestureDetector(
                onTap: _ready ? widget.onTogglePlay : null,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xE6FFFFFF).withValues(alpha: _ready ? 0.9 : 0),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _ready
                      ? Text(
                          widget.isPlaying ? '❙❙' : '▶',
                          style: const TextStyle(color: AppColors.videoGradB, fontSize: 20),
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 4,
                        color: Colors.white.withValues(alpha: 0.3),
                        alignment: Alignment.centerLeft,
                        child: _ready
                            ? ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: _controller!,
                                builder: (context, value, _) {
                                  final total = value.duration.inMilliseconds;
                                  final pos = value.position.inMilliseconds;
                                  final factor = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
                                  return FractionallySizedBox(
                                    widthFactor: factor,
                                    child: Container(color: Colors.white),
                                  );
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_durationLabel(), style: AppFonts.inter(size: 11, weight: FontWeight.w600)),
                        GestureDetector(
                          onTap: _ready
                              ? () {
                                  _controller!.seekTo(Duration.zero);
                                  if (!widget.isPlaying) widget.onTogglePlay();
                                }
                              : null,
                          child: Text('⟲ ⛶', style: AppFonts.inter(size: 11, weight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel() {
    if (_ready) {
      final d = _controller!.value.duration;
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return widget.duration;
  }
}
