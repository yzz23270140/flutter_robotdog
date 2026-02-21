import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Android/iOS/桌面平台 MQTT 客户端
class PlatformMqttClient {
  final String topic = 'esp8266sor';
  final String _clientId =
      'flutter_android_${DateTime.now().millisecondsSinceEpoch}';

  // ===== ✅ 改成你的腾讯云服务器 =====
  static const String _mqttServer = '111.229.96.119';  // ← 你的腾讯云公网IP
  static const int    _mqttPort   = 1883;              // ← TCP 端口
  static const String _mqttUser   = 'esp8266';         // ← 服务器上创建的用户名
  static const String _mqttPass   = 'renesas';               // ← 你设置的密码（替换成真实密码）

  MqttServerClient? _client;
  final _sensorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  

  Stream<Map<String, dynamic>> get sensorStream => _sensorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
 
  
  Future<void> connect() async {
    // 【关键区别】Android 用 TCP 连接，不是 WebSocket
    _client = MqttServerClient(_mqttServer, _clientId);
    _client!.port = _mqttPort; // TCP 端口，不是 8083
    _client!.keepAlivePeriod = 60;
    _client!.logging(on: false);
    _client!.setProtocolV311();
    _client!.autoReconnect = true; // 【新增】自动重连，保证数据实时性
    _client!.resubscribeOnAutoReconnect = true; // 重连后自动重新订阅

    _client!.onDisconnected = () {
      debugPrint('❌ MQTT 断开连接');
      _connectionController.add(false);
    };
    _client!.onConnected = () {
      debugPrint('✅ MQTT 连接成功 (Android/TCP)');
      _connectionController.add(true);
    };
    _client!.onAutoReconnect = () {
      debugPrint('🔄 MQTT 正在自动重连...');
    };
    _client!.onAutoReconnected = () {
      debugPrint('✅ MQTT 自动重连成功');
      _connectionController.add(true);
    };
    _client!.onSubscribed =
        (String topic) => debugPrint('✅ 已订阅: $topic');

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .authenticateAs(_mqttUser, _mqttPass)  // ← 关键！加上认证
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    _client!.connectionMessage = connMess;

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('❌ MQTT 连接错误: $e');
      _connectionController.add(false);
      _client!.disconnect();
      return;
    }

    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) {
            _sensorController.add(data);
          }
        } catch (e) {
          debugPrint('❌ JSON 解析错误: $e');
        }
      });
    }
  }

  void dispose() {
    _sensorController.close();
    _connectionController.close();
    _client?.disconnect();
  }
}