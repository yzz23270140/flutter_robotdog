import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

/// Web 平台 MQTT 客户端
class PlatformMqttClient {
  final String topic = 'esp8266sor';
  final String _clientId =
      'flutter_web_${DateTime.now().millisecondsSinceEpoch}';

  static const String _mqttWsUrl = 'ws://111.229.96.119/mqtt';  // ← WebSocket 地址
  static const int    _mqttPort  = 8083;                         // ← WebSocket 端口
  static const String _mqttUser  = 'esp8266';                    // ← 用户名
  static const String _mqttPass  = 'renesas';  

  MqttBrowserClient? _client;
  final _sensorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get sensorStream => _sensorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> connect() async {
    _client = MqttBrowserClient(_mqttWsUrl, _clientId);
    _client!.port =  _mqttPort;
    _client!.keepAlivePeriod = 60;
    _client!.logging(on: false);
    _client!.setProtocolV311();
    _client!.autoReconnect = true;                      
    _client!.resubscribeOnAutoReconnect = true;       
    _client!.onDisconnected = () {
      debugPrint('❌ MQTT 断开连接');
      _connectionController.add(false);
    };
    _client!.onConnected = () {
      debugPrint('✅ MQTT 连接成功 (Web/WebSocket)');
      _connectionController.add(true);
    };
    _client!.onSubscribed =
        (String topic) => debugPrint('✅ 已订阅: $topic');

    _client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .authenticateAs(_mqttUser, _mqttPass) 
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