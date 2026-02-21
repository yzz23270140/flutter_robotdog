// lib/live_player_widget.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LivePlayerWidget extends StatefulWidget {
  final String serverIp;
  final double height;
  const LivePlayerWidget({super.key, required this.serverIp, this.height = 200});

  @override
  State<LivePlayerWidget> createState() => _LivePlayerWidgetState();
}

class _LivePlayerWidgetState extends State<LivePlayerWidget> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _useFlv = true;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMsg = '';

  // 使用 widget.serverIp 而不是硬编码或错误的 ${...}
  String get _flvUrl => 'http://${widget.serverIp}:8080/live/camera.flv';
  String get _hlsUrl => 'http://${widget.serverIp}:8080/live/camera.m3u8';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _startPlay();
    WakelockPlus.enable();
  }

  Future<void> _startPlay() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      // 释放之前的控制器
      if (_controller.value.isInitialized) {
        await _controller.dispose();
      }
      
      final url = _useFlv ? _flvUrl : _hlsUrl;
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      // 添加监听器
      _controller.addListener(_playerListener);
      
      // 初始化并自动播放
      await _controller.initialize();
      await _controller.play();
    } catch (e) {
      setState(() { _hasError = true; _isLoading = false; _errorMsg = '连接失败: $e'; });
    }
  }

  void _playerListener() {
    if (_controller.value.hasError) {
      setState(() { _hasError = true; _isLoading = false; _errorMsg = '播放错误'; });
    } else if (_controller.value.isPlaying) {
      setState(() { _isLoading = false; _hasError = false; });
    } else if (_controller.value.isInitialized && !_controller.value.isPlaying && !_controller.value.hasError) {
      setState(() { _isLoading = true; _hasError = false; });
    }
  }

  void switchProtocol() {
    _useFlv = !_useFlv;
    _startPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
      WakelockPlus.disable();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller.value.isInitialized) {
        _controller.play();
      }
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_playerListener);
    _controller.dispose();
    WakelockPlus.disable();
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
          if (_controller.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else
            Container(color: Colors.black),
          if (_isLoading)
            Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
          if (_hasError)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.videocam_off, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                Text(_errorMsg, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _startPlay, child: const Text('重试')),
              ]),
            ),
          Positioned(
            right: 8,
            top: 8,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black54, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero),
              onPressed: switchProtocol,
              child: Text(_useFlv ? 'FLV' : 'HLS', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}