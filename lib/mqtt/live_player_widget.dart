// lib/live_player_widget.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LivePlayerWidget extends StatefulWidget {
  final String serverIp;
  final double height;

  const LivePlayerWidget({
    super.key,
    required this.serverIp,
    this.height = 200,
  });

  @override
  State<LivePlayerWidget> createState() => _LivePlayerWidgetState();
}

class _LivePlayerWidgetState extends State<LivePlayerWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _startupTimer;
  Duration _lastPosition = Duration.zero;

  bool _useFlv = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isRecovering = false;
  int _retryCount = 0;
  String _errorMsg = '';

  String get _flvUrl =>
      'http://${widget.serverIp}:8081/live/camera.flv';
  String get _hlsUrl =>
      'http://${widget.serverIp}:8080/live/camera.m3u8?_t=${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initPlayer());
  }

  Future<void> _initPlayer() async {
    await _startPlay();
    await WakelockPlus.enable();
  }

  Future<void> _startPlay() async {
    _startupTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMsg = '';
    });

    try {
      final oldController = _controller;
      if (oldController != null) {
        oldController.removeListener(_playerListener);
        await oldController.dispose();
      }

      final url = _useFlv ? _flvUrl : _hlsUrl;
      final nextController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      _controller = nextController;
      _lastPosition = Duration.zero;
      nextController.addListener(_playerListener);

      await nextController.initialize();
      if (!mounted || _controller != nextController) {
        return;
      }

      await nextController.play();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      _retryCount = 0;

      _startupTimer = Timer(const Duration(seconds: 6), () {
        _handleStartupTimeout(nextController);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMsg = '连接失败: $e';
      });
    }
  }

  void _playerListener() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final hasError = controller.value.hasError;
    final isBuffering = controller.value.isBuffering;
    final position = controller.value.position;
    if (position > _lastPosition) {
      _lastPosition = position;
    }

    if (hasError) {
      final detail = controller.value.errorDescription ?? '播放错误（可能是编码/协议不兼容）';
      if (detail.contains('404') && _retryCount < 2) {
        _retryCount += 1;
        _startupTimer?.cancel();
        unawaited(_startPlay());
        return;
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMsg = detail;
      });
      return;
    }

    if (_isLoading != isBuffering) {
      setState(() {
        _isLoading = isBuffering;
        _hasError = false;
      });
    }
  }

  void _handleStartupTimeout(VideoPlayerController target) {
    if (!mounted || _controller != target || _hasError) {
      return;
    }

    final noFrameProgress = _lastPosition <= Duration.zero;
    final stillLoading = _isLoading || target.value.isBuffering || noFrameProgress;
    if (!stillLoading || _isRecovering) {
      return;
    }

    if (!_useFlv) {
      _isRecovering = true;
      _useFlv = true;
      _startPlay().whenComplete(() {
        _isRecovering = false;
      });
      return;
    }

    setState(() {
      _hasError = true;
      _isLoading = false;
      _errorMsg = 'HLS/FLV 都未成功出画面。\n'
          '请检查：\n'
          '1) HLS 走 Nginx 8080，是否持续产生 camera.m3u8 与 ts 分片；\n'
          '2) HTTP-FLV 走 SRS 8081，URL 是否可在 VLC 打开；\n'
          '3) 推流建议 libx264 + GOP=25 + yuv420p，避免 ExoPlayer 解复用错误。';
    });
  }

  void switchProtocol() {
    _retryCount = 0;
    _useFlv = !_useFlv;
    unawaited(_startPlay());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final controller = _controller;
    if (controller == null) return;

    if (state == AppLifecycleState.paused) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
      unawaited(WakelockPlus.disable());
    } else if (state == AppLifecycleState.resumed) {
      if (controller.value.isInitialized) {
        controller.play();
      }
      unawaited(WakelockPlus.enable());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startupTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_controller?.value.isInitialized ?? false)
            AspectRatio(
              aspectRatio: _controller?.value.aspectRatio ?? (16 / 9),
              child: VideoPlayer(_controller!),
            )
          else
            Container(color: Colors.black),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_hasError)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, color: Colors.red, size: 32),
                    const SizedBox(height: 6),
                    Text(
                      _errorMsg,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _startPlay, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 8,
            top: 8,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
              ),
              onPressed: switchProtocol,
              child: Text(
                _useFlv ? 'FLV' : 'HLS',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
