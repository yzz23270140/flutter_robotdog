import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:robotdog/mqtt/mqtt_factory.dart';//使用条件编译的统一入口
import 'package:robotdog/mqtt/live_player_widget.dart';

/// 程序入口
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RobotDog助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F3),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}


class _AppBarTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AppBarTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const TextSpan(text: '  '),
            TextSpan(
              text: subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/* ================== 首页 ================== */

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final MqttService _mqttService = MqttService();
  bool _isConnected = false;
  DateTime? _lastUpdate;

  // 阈值状态 - 存储用户设置的阈值
  Map<String, Map<String, double>> _thresholds = {
    'temperature': {'warningHigh': 30, 'dangerHigh': 35},
    'humidity': {'warningHigh': 60, 'dangerHigh': 80},
    'co': {'warningHigh': 0, 'dangerHigh': 50},
    "tvoc": {'warningHigh': 0, 'dangerHigh': 6000},
  };

  Map<String, dynamic> _latestData = {
    "temperature": "--",
    "humidity": "--",
    "co": "--",
    "tvoc": "--",
  };

  @override
  void initState() {
    super.initState();
    _mqttService.connect();

    _mqttService.connectionStream.listen((connected) {
      setState(() => _isConnected = connected);
    });

    _mqttService.sensorStream.listen((data) {
      setState(() {
        _latestData = data;
        _lastUpdate = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }

  // 更新阈值的回调方法
  void _updateThresholds(Map<String, Map<String, double>> newThresholds) {
    setState(() {
      _thresholds = newThresholds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SensorPage(
        data: _latestData,
        isConnected: _isConnected,
        lastUpdate: _lastUpdate,
      ),
      const CameraPage(),
      AlertPage(
        data: _latestData,
        thresholds: _thresholds,            // 传入阈值
        onUpdateThresholds: _updateThresholds, // 传入回调
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _index,
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 65,
            indicatorColor: const Color(0xFFDCEAD6),
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.sensors_outlined),
                selectedIcon: Icon(Icons.sensors),
                label: '传感器',
              ),
              NavigationDestination(
                icon: Icon(Icons.videocam_outlined),
                selectedIcon: Icon(Icons.videocam),
                label: '摄像头',
              ),
              NavigationDestination(
                icon: Icon(Icons.warning_amber_rounded),
                selectedIcon: Icon(Icons.warning_rounded),
                label: '警告',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================== MQTT 服务（跨平台封装） ================== */

class MqttService {
  // 使用条件编译的平台客户端
  final PlatformMqttClient _platformClient = PlatformMqttClient();

  Stream<Map<String, dynamic>> get sensorStream =>
      _platformClient.sensorStream;
  Stream<bool> get connectionStream => _platformClient.connectionStream;

  Future<void> connect() async {
    await _platformClient.connect();
  }

  void dispose() {
    _platformClient.dispose();
  }
}

/* ================== 传感器页面 ================== */
// AppBar title 改为单行 Text，副标题移到 background 中
// 避免 Column 在 AppBar 收缩时溢出

class SensorPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isConnected;
  final DateTime? lastUpdate;

  const SensorPage({
    super.key,
    required this.data,
    required this.isConnected,
    this.lastUpdate,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // AppBar - title 只放单行文字，副标题放 background
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF4CAF50),
          flexibleSpace: FlexibleSpaceBar(
            title: const _AppBarTitle(
              title: 'RobotDog助手',
              subtitle: '环境监测面板',
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
                ),
              ),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.eco, color: Colors.white12, size: 90),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConnectionStatusCard(
                  isConnected: isConnected,
                  lastUpdate: lastUpdate,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '实时传感器数据',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const Spacer(),
                    if (lastUpdate != null)
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(lastUpdate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // 温度独占一行
                _SensorCard(
                  title: '温度',
                  value: '${data["temperature"]}',
                  unit: '°C',
                  icon: Icons.thermostat_rounded,
                  gradient: const [Color(0xFFFF8A65), Color(0xFFFF5722)],
                  bgColor: const Color(0xFFFFF3E0),
                  minVal: -10,
                  maxVal: 50,
                  minLabel: '-10°C',
                  maxLabel: '50°C',
                ),
                const SizedBox(height: 12),

                // 湿度独占一行
                _SensorCard(
                  title: '湿度',
                  value: '${data["humidity"]}',
                  unit: '%',
                  icon: Icons.water_drop_rounded,
                  gradient: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                  bgColor: const Color(0xFFE1F5FE),
                  minVal: 0,
                  maxVal: 100,
                  minLabel: '0%',
                  maxLabel: '100%',
                ),
                const SizedBox(height: 12),

                // 气体浓度 + TVOC：大屏并排，小屏自动换行，避免卡片内部溢出
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 720;
                    final coCard = _SensorCard(
                      title: '一氧化碳气体浓度',
                      value: '${data["co"]}',
                      unit: 'ppm',
                      icon: Icons.cloud_rounded,
                      gradient: const [Color(0xFFAED581), Color(0xFF689F38)],
                      bgColor: const Color(0xFFF1F8E9),
                      minVal: 0,
                      maxVal: 100,
                      minLabel: '0ppm',
                      maxLabel: '100ppm',
                    );
                    final tvocCard = _SensorCard(
                      title: '有机挥发性气体',
                      value: '${data["tvoc"]}',
                      unit: 'μg/m³',
                      icon: Icons.wb_sunny_rounded,
                      gradient: const [Color(0xFFFFD54F), Color(0xFFF9A825)],
                      bgColor: const Color(0xFFFFFDE7),
                      minVal: 0,
                      maxVal: 10000,
                      minLabel: '0μg/m³',
                      maxLabel: '10000μg/m³',
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          coCard,
                          const SizedBox(height: 12),
                          tvocCard,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: coCard),
                        const SizedBox(width: 12),
                        Expanded(child: tvocCard),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),
                _DeviceInfoCard(isConnected: isConnected),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ================== 传感器卡片组件 ================== */

class _SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final List<Color> gradient;
  final Color bgColor;
  final double minVal;
  final double maxVal;
  final String minLabel;
  final String maxLabel;

  const _SensorCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
    required this.bgColor,
    this.minVal = 0,
    this.maxVal = 100,
    this.minLabel = '0',
    this.maxLabel = '100',
  });

  @override
  Widget build(BuildContext context) {
    final numericValue = double.tryParse(value);
    double progress = 0.0;
    if (numericValue != null && maxVal > minVal) {
      progress = ((numericValue - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
    }

    Color statusColor = gradient[1];
    String statusText = '正常';
    if (progress > 0.8) {
      statusColor = Colors.red;
      statusText = '偏高';
    } else if (progress > 0.6) {
      statusColor = Colors.orange;
      statusText = '注意';
    } else if (progress < 0.2 && numericValue != null) {
      statusColor = const Color(0xFF2196F3);
      statusText = '偏低';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (numericValue != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: gradient[1],
                    height: 1,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: numericValue != null ? progress : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: progress > 0.8
                                ? [Colors.orange, Colors.red]
                                : gradient,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(minLabel,
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                if (numericValue != null)
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(maxLabel,
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ================== 连接状态卡片 ================== */

class _ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final DateTime? lastUpdate;

  const _ConnectionStatusCard({
    required this.isConnected,
    this.lastUpdate,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '暂无数据';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isConnected ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isConnected ? const Color(0xFF4CAF50) : Colors.red)
                  .withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? const Color(0xFF4CAF50) : Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'MQTT 已连接' : 'MQTT 未连接',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isConnected
                        ? const Color(0xFF2E7D32)
                        : Colors.red[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '111.229.96.119:1883',    
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('最近更新',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              const SizedBox(height: 2),
              Text(
                _formatTime(lastUpdate),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isConnected
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ================== 设备信息卡片 ================== */

class _DeviceInfoCard extends StatelessWidget {
  final bool isConnected;

  const _DeviceInfoCard({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.developer_board,
                    color: Colors.grey[700], size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                '设备信息',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: '设备', value: 'ESP8266'),
          _InfoRow(label: '主题', value: 'esp8266sor'),
          _InfoRow(label: '协议', value: 'MQTT v3.1.1'),
          _InfoRow(label: '传输', value: kIsWeb ? 'WebSocket (8083)' : 'TCP (1883)'),
          _InfoRow(
            label: '状态',
            value: isConnected ? '在线' : '离线',
            valueColor: isConnected ? const Color(0xFF4CAF50) : Colors.red,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

/* ================== 摄像头页面 ================== */

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF4CAF50),
          flexibleSpace: FlexibleSpaceBar(
            title: const _AppBarTitle(
              title: 'RobotDog助手',
              subtitle: '远程监控',
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
                ),
              ),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.videocam, color: Colors.white12, size: 90),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '摄像头画面',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LivePlayerWidget(
                  serverIp: '111.229.96.119', // <-- 替换为实际 IP 或域名（不带 http://）
                  height: 200, // 或更大，例如 240，或用 MediaQuery 做自适应
                  ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF4CAF50),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '后续将接入树莓派视频流（RTSP/HTTP），实现远程实时监控',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ================== 警告页面 ================== */
// 新增 thresholds 和 onUpdateThresholds 参数
// 用用户设置的阈值替代硬编码判断

class AlertPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, Map<String, double>> thresholds;
  final Function(Map<String, Map<String, double>>) onUpdateThresholds;

  const AlertPage({
    super.key,
    required this.data,
    required this.thresholds,
    required this.onUpdateThresholds,
  });

  List<_AlertInfo> _generateAlerts() {
    final alerts = <_AlertInfo>[];

    final temp = double.tryParse('${data["temperature"]}');
    final humidity = double.tryParse('${data["humidity"]}');
    final co = double.tryParse('${data["co"]}');

    // 【改动】使用动态阈值替代硬编码
    final tempThreshold = thresholds['temperature']!;
    final humidityThreshold = thresholds['humidity']!;
    final coThreshold = thresholds['co']!;

    if (temp != null) {
      if (temp > tempThreshold['dangerHigh']!) {
        alerts.add(_AlertInfo(
            '高温告警', '温度 $temp°C,超过安全阈值 ${tempThreshold['dangerHigh']}°C!',
            AlertLevel.danger));
      } else if (temp > tempThreshold['warningHigh']!) {
        alerts.add(_AlertInfo(
            '温度提醒', '温度 $temp°C,超过提醒阈值 ${tempThreshold['warningHigh']}°C',
            AlertLevel.warning));
      } else {
        alerts.add(_AlertInfo('温度正常', '温度 $temp°C,处于安全范围', AlertLevel.normal));
      }
    }

    if (humidity != null) {
      if (humidity > humidityThreshold['dangerHigh']!) {
        alerts.add(_AlertInfo(
            '湿度告警', '湿度 $humidity%,超过安全阈值 ${humidityThreshold['dangerHigh']}%!',
            AlertLevel.danger));
      } else if (humidity > humidityThreshold['warningHigh']!) {
        alerts.add(_AlertInfo(
            '湿度提醒', '湿度 $humidity%,超过提醒阈值 ${humidityThreshold['warningHigh']}%',
            AlertLevel.warning));
      } else {
        alerts
            .add(_AlertInfo('湿度正常', '湿度 $humidity%,处于正常范围', AlertLevel.normal));
      }
    }

    if (co != null) {
      if (co > coThreshold['dangerHigh']!) {
        alerts.add(_AlertInfo(
            '气体告警', '气体浓度 $co%，超过安全阈值 ${coThreshold['dangerHigh']}%!',
            AlertLevel.danger));
      } else if (co > coThreshold['warningHigh']!) {
        alerts.add(_AlertInfo(
            '气体提醒', '气体浓度 $co%，超过提醒阈值 ${coThreshold['warningHigh']}%',
            AlertLevel.warning));
      } else {
        alerts
            .add(_AlertInfo('气体正常', '气体浓度 $co%,处于安全范围', AlertLevel.normal));
      }
    }

    if (alerts.isEmpty) {
      alerts.add(_AlertInfo('暂无数据', '等待传感器数据接入...', AlertLevel.normal));
    }

    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _generateAlerts();
    final dangerCount =
        alerts.where((a) => a.level == AlertLevel.danger).length;
    final warningCount =
        alerts.where((a) => a.level == AlertLevel.warning).length;
    final normalCount = alerts.length - dangerCount - warningCount;

    return CustomScrollView(
      slivers: [
         SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF4CAF50),
          flexibleSpace: FlexibleSpaceBar(
            title: const _AppBarTitle(
              title: 'Little助手',
              subtitle: '安全监控',
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
                ),
              ),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.shield, color: Colors.white12, size: 90),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _AlertCountBadge(
                      count: dangerCount,
                      label: '告警',
                      color: Colors.red,
                    ),
                    const SizedBox(width: 10),
                    _AlertCountBadge(
                      count: warningCount,
                      label: '提醒',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    _AlertCountBadge(
                      count: normalCount,
                      label: '正常',
                      color: const Color(0xFF4CAF50),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '警告信息',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '共 ${alerts.length} 条',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...alerts.map((alert) => _AlertCard(info: alert)),
                const SizedBox(height: 12),

                // 【改动】阈值设置 - 可点击跳转到设置页面
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<Map<String, Map<String, double>>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ThresholdSettingsPage(thresholds: thresholds),
                      ),
                    );
                    if (result != null) {
                      onUpdateThresholds(result);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune,
                              color: Color(0xFF9C27B0), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '阈值设置',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '自定义温度、湿度、气体警告阈值',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ================== 【新增】阈值设置页面 ================== */

class ThresholdSettingsPage extends StatefulWidget {
  final Map<String, Map<String, double>> thresholds;

  const ThresholdSettingsPage({super.key, required this.thresholds});

  @override
  State<ThresholdSettingsPage> createState() => _ThresholdSettingsPageState();
}

class _ThresholdSettingsPageState extends State<ThresholdSettingsPage> {
  late Map<String, Map<String, double>> _editThresholds;

  @override
  void initState() {
    super.initState();
    // 深拷贝，避免直接修改原数据
    _editThresholds = {
      'temperature': Map.from(widget.thresholds['temperature']!),
      'humidity': Map.from(widget.thresholds['humidity']!),
      'co': Map.from(widget.thresholds['co']!),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F3),
      appBar: AppBar(
        title: const Text('阈值设置'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              // 恢复默认值
              setState(() {
                _editThresholds = {
                  'temperature': {'warningHigh': 30, 'dangerHigh': 35},
                  'humidity': {'warningHigh': 60, 'dangerHigh': 80},
                  'co': {'warningHigh': 30, 'dangerHigh': 50},
                };
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已恢复默认阈值'),
                  backgroundColor: Color(0xFF4CAF50),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('恢复默认', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明卡片
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '拖动滑块设置警告阈值。超过"提醒"值显示黄色警告，超过"告警"值显示红色告警。',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700], height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 温度阈值设置
            _ThresholdSection(
              title: '温度阈值',
              icon: Icons.thermostat_rounded,
              gradient: const [Color(0xFFFF8A65), Color(0xFFFF5722)],
              unit: '°C',
              min: -10,
              max: 60,
              warningValue: _editThresholds['temperature']!['warningHigh']!,
              dangerValue: _editThresholds['temperature']!['dangerHigh']!,
              onWarningChanged: (v) {
                setState(() {
                  _editThresholds['temperature']!['warningHigh'] = v;
                  // 确保告警值 >= 提醒值
                  if (_editThresholds['temperature']!['dangerHigh']! < v) {
                    _editThresholds['temperature']!['dangerHigh'] = v;
                  }
                });
              },
              onDangerChanged: (v) {
                setState(() {
                  _editThresholds['temperature']!['dangerHigh'] = v;
                  // 确保提醒值 <= 告警值
                  if (_editThresholds['temperature']!['warningHigh']! > v) {
                    _editThresholds['temperature']!['warningHigh'] = v;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // 湿度阈值设置
            _ThresholdSection(
              title: '湿度阈值',
              icon: Icons.water_drop_rounded,
              gradient: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
              unit: '%',
              min: 0,
              max: 100,
              warningValue: _editThresholds['humidity']!['warningHigh']!,
              dangerValue: _editThresholds['humidity']!['dangerHigh']!,
              onWarningChanged: (v) {
                setState(() {
                  _editThresholds['humidity']!['warningHigh'] = v;
                  if (_editThresholds['humidity']!['dangerHigh']! < v) {
                    _editThresholds['humidity']!['dangerHigh'] = v;
                  }
                });
              },
              onDangerChanged: (v) {
                setState(() {
                  _editThresholds['humidity']!['dangerHigh'] = v;
                  if (_editThresholds['humidity']!['warningHigh']! > v) {
                    _editThresholds['humidity']!['warningHigh'] = v;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // 气体浓度阈值设置
            _ThresholdSection(
              title: '气体浓度阈值',
              icon: Icons.cloud_rounded,
              gradient: const [Color(0xFFAED581), Color(0xFF689F38)],
              unit: '%',
              min: 0,
              max: 100,
              warningValue: _editThresholds['co']!['warningHigh']!,
              dangerValue: _editThresholds['co']!['dangerHigh']!,
              onWarningChanged: (v) {
                setState(() {
                  _editThresholds['co']!['warningHigh'] = v;
                  if (_editThresholds['co']!['dangerHigh']! < v) {
                    _editThresholds['co']!['dangerHigh'] = v;
                  }
                });
              },
              onDangerChanged: (v) {
                setState(() {
                  _editThresholds['co']!['dangerHigh'] = v;
                  if (_editThresholds['co']!['warningHigh']! > v) {
                    _editThresholds['co']!['warningHigh'] = v;
                  }
                });
              },
            ),

            const SizedBox(height: 30),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _editThresholds);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ 阈值已保存'),
                      backgroundColor: Color(0xFF4CAF50),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  '保存设置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/* ================== 【新增】阈值设置区块组件 ================== */

class _ThresholdSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String unit;
  final double min;
  final double max;
  final double warningValue;
  final double dangerValue;
  final ValueChanged<double> onWarningChanged;
  final ValueChanged<double> onDangerChanged;

  const _ThresholdSection({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.unit,
    required this.min,
    required this.max,
    required this.warningValue,
    required this.dangerValue,
    required this.onWarningChanged,
    required this.onDangerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 提醒阈值滑块
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('提醒阈值',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${warningValue.round()} $unit',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.orange,
              inactiveTrackColor: Colors.orange.withOpacity(0.15),
              thumbColor: Colors.orange,
              overlayColor: Colors.orange.withOpacity(0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: warningValue,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onWarningChanged,
            ),
          ),

          const SizedBox(height: 8),

          // 告警阈值滑块
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('告警阈值',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${dangerValue.round()} $unit',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.red,
              inactiveTrackColor: Colors.red.withOpacity(0.15),
              thumbColor: Colors.red,
              overlayColor: Colors.red.withOpacity(0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: dangerValue,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onDangerChanged,
            ),
          ),

          // 区间示意
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${min.round()} $unit',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                Text('${max.round()} $unit',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ================== 警告相关组件 ================== */

enum AlertLevel { normal, warning, danger }

class _AlertInfo {
  final String title;
  final String message;
  final AlertLevel level;
  _AlertInfo(this.title, this.message, this.level);
}

class _AlertCountBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _AlertCountBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final _AlertInfo info;

  const _AlertCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final color = switch (info.level) {
      AlertLevel.normal => const Color(0xFF4CAF50),
      AlertLevel.warning => Colors.orange,
      AlertLevel.danger => Colors.red,
    };
    final icon = switch (info.level) {
      AlertLevel.normal => Icons.check_circle_rounded,
      AlertLevel.warning => Icons.warning_amber_rounded,
      AlertLevel.danger => Icons.error_rounded,
    };
    final bgColor = switch (info.level) {
      AlertLevel.normal => const Color(0xFFF8FBF6),
      AlertLevel.warning => const Color(0xFFFFFBF5),
      AlertLevel.danger => const Color(0xFFFFF8F7),
    };
    final levelText = switch (info.level) {
      AlertLevel.normal => '正常',
      AlertLevel.warning => '提醒',
      AlertLevel.danger => '告警',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      info.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        levelText,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  info.message,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}