import 'dart:async';

/// Stub 实现 - 仅用于编译占位，实际不会被调用
class PlatformMqttClient {
  final String topic = 'esp8266sor';
  final _sensorController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get sensorStream => _sensorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> connect() async {
    throw UnsupportedError('当前平台不支持 MQTT');
  }

  void dispose() {
    _sensorController.close();
    _connectionController.close();
  }
}