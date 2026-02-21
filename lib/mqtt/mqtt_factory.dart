// 条件导入：根据平台自动选择实现
// dart.library.io → Android/iOS/桌面
// dart.library.html → Web
export 'mqtt_stub.dart'
    if (dart.library.io) 'mqtt_io.dart'
    if (dart.library.html) 'mqtt_web.dart';