import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerScreen extends StatefulWidget {
  final AssetEntity video;
  final List<AssetEntity>? allVideos;
  final int? initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.allVideos,
    this.initialIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLandscape = false; // Track if in landscape mode
  bool _isLocked = false; // Lock screen state
  bool _isDragging = false; // Slider dragging state
  double _dragValue = 0.0; // Slider drag value

  AssetEntity get _currentVideo =>
      widget.allVideos?[_currentIndex] ?? widget.video;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _initializeVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _checkVideoOrientation();
  }

  Future<void> _checkVideoOrientation() async {
    final width = _currentVideo.width;
    final height = _currentVideo.height;

    if (width > height) {
      setState(() => _isLandscape = true);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      setState(() => _isLandscape = false);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Future<void> _initializeVideo() async {
    await _player?.dispose();

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _player = null;
      _videoController = null;
    });

    try {
      final file = await _currentVideo.file;

      if (file == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
        return;
      }

      final player = Player();
      final videoController = VideoController(player);

      _player = player;
      _videoController = videoController;

      player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() => _isPlaying = playing);
        }
      });

      player.stream.position.listen((position) {
        if (mounted && !_isDragging) {
          setState(() => _position = position);
        }
      });

      player.stream.duration.listen((duration) {
        if (mounted) {
          setState(() => _duration = duration);
        }
      });

      player.stream.buffering.listen((buffering) {
        if (mounted && !buffering) {
          setState(() => _isLoading = false);
        }
      });

      await player.open(Media(file.path));
      await player.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isPlaying && !_isLocked) {
            setState(() => _showControls = false);
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_player == null) return;

    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying && !_isLocked) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) {
      setState(() => _showControls = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isLocked) {
          setState(() => _showControls = false);
        }
      });
      return;
    }
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _showControls = false;
      } else {
        _showControls = true;
      }
    });
  }

  void _changePlaybackSpeed() {
    if (_player == null) return;

    final currentSpeed = _player!.state.rate;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexWhere(
      (s) => (s - currentSpeed).abs() < 0.01,
    );
    final effectiveIndex = currentIndex == -1 ? 2 : currentIndex;
    final nextIndex = (effectiveIndex + 1) % speeds.length;

    _player!.setRate(speeds[nextIndex]);
  }

  void _showSubtitleDialog() {
    if (_player == null) return;

    final tracks = _player!.state.tracks.subtitle;
    final currentTrack = _player!.state.track.subtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subtitles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: tracks.length + 1, // +1 for "None"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      title: const Text(
                        'None',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: currentTrack == VideoTrack.no()
                          ? const Icon(Icons.check, color: Color(0xFFF37121))
                          : null,
                      onTap: () {
                        _player!.setSubtitleTrack(SubtitleTrack.no());
                        Navigator.pop(context);
                      },
                    );
                  }
                  final track = tracks[index - 1];
                  return ListTile(
                    title: Text(
                      track.title ?? track.language ?? 'Track $index',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: currentTrack == track
                        ? const Icon(Icons.check, color: Color(0xFFF37121))
                        : null,
                    onTap: () {
                      _player!.setSubtitleTrack(track);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousVideo() {
    if (widget.allVideos == null || _currentIndex <= 0) return;
    setState(() => _currentIndex--);
    _checkVideoOrientation();
    _initializeVideo();
  }

  void _nextVideo() {
    if (widget.allVideos == null ||
        _currentIndex >= widget.allVideos!.length - 1) {
      return;
    }
    setState(() => _currentIndex++);
    _checkVideoOrientation();
    _initializeVideo();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Reset orientation to portrait when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Video Player
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
                    )
                  : _hasError
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.white70,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Unable to load video',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  : _videoController != null
                  ? Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                    )
                  : const SizedBox(),
            ),

            // Lock Screen Overlay (Only Unlock Button)
            if (_isLocked && _showControls)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      icon: const Icon(Icons.lock, color: Colors.white),
                      onPressed: _toggleLock,
                      tooltip: 'Unlock',
                    ),
                  ),
                ),
              ),

            // Controls Overlay (Standard)
            if (_showControls && !_hasError && !_isLoading && !_isLocked)
              IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black45,
                  child: Column(
                    children: [
                      // Top Bar
                      SafeArea(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentVideo.title ?? 'Video',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Subtitles
                            IconButton(
                              icon: const Icon(
                                Icons.closed_caption,
                                color: Colors.white,
                              ),
                              onPressed: _showSubtitleDialog,
                            ),
                            // Playback speed
                            TextButton(
                              onPressed: _changePlaybackSpeed,
                              child: Text(
                                '${_player?.state.rate ?? 1.0}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Lock Button
                            IconButton(
                              icon: const Icon(
                                Icons.lock_open,
                                color: Colors.white,
                              ),
                              onPressed: _toggleLock,
                            ),
                            // Orientation toggle button
                            IconButton(
                              icon: Icon(
                                _isLandscape
                                    ? Icons.screen_lock_portrait
                                    : Icons.screen_lock_landscape,
                                color: Colors.white,
                              ),
                              onPressed: _toggleOrientation,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Center Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous button
                          IconButton(
                            iconSize: 48,
                            icon: Icon(
                              Icons.skip_previous,
                              color:
                                  (widget.allVideos != null &&
                                      _currentIndex > 0)
                                  ? Colors.white
                                  : Colors.white30,
                            ),
                            onPressed:
                                (widget.allVideos != null && _currentIndex > 0)
                                ? _previousVideo
                                : null,
                          ),

                          const SizedBox(width: 24),

                          // Play/Pause button
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 64,
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ),

                          const SizedBox(width: 24),

                          // Next button
                          IconButton(
                            iconSize: 48,
                            icon: Icon(
                              Icons.skip_next,
                              color:
                                  (widget.allVideos != null &&
                                      _currentIndex <
                                          widget.allVideos!.length - 1)
                                  ? Colors.white
                                  : Colors.white30,
                            ),
                            onPressed:
                                (widget.allVideos != null &&
                                    _currentIndex <
                                        widget.allVideos!.length - 1)
                                ? _nextVideo
                                : null,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom Controls
                      SafeArea(
                        child: Column(
                          children: [
                            // Progress Bar
                            if (_player != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 16,
                                    ),
                                  ),
                                  child: Slider(
                                    value:
                                        (_isDragging
                                                ? _dragValue
                                                : _position.inMilliseconds
                                                      .toDouble())
                                            .clamp(
                                              0.0,
                                              _duration.inMilliseconds
                                                          .toDouble() >
                                                      0
                                                  ? _duration.inMilliseconds
                                                        .toDouble()
                                                  : 1.0,
                                            ),
                                    max: _duration.inMilliseconds.toDouble() > 0
                                        ? _duration.inMilliseconds.toDouble()
                                        : 1.0,
                                    activeColor: const Color(0xFFF37121),
                                    inactiveColor: Colors.white30,
                                    onChanged: (value) {
                                      setState(() {
                                        _isDragging = true;
                                        _dragValue = value;
                                      });
                                    },
                                    onChangeStart: (value) {
                                      setState(() {
                                        _isDragging = true;
                                        _dragValue = value;
                                      });
                                      _player!.pause();
                                    },
                                    onChangeEnd: (value) {
                                      _player!.seek(
                                        Duration(milliseconds: value.toInt()),
                                      );
                                      setState(() {
                                        _isDragging = false;
                                      });
                                      _player!.play();
                                    },
                                  ),
                                ),
                              ),

                            // Time and Volume
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${_formatDuration(_isDragging ? Duration(milliseconds: _dragValue.toInt()) : _position)} / ${_formatDuration(_duration)}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      (_player?.state.volume ?? 100.0) > 0
                                          ? Icons.volume_up
                                          : Icons.volume_off,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      if (_player == null) return;
                                      final currentVol = _player!.state.volume;
                                      _player!.setVolume(
                                        currentVol > 0 ? 0.0 : 100.0,
                                      );
                                    },
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}
