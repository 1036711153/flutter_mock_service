import 'package:flutter_mock_service/flutter_mock_service.dart';
import 'package:flutter_mock_service_example/app_demo.dart';
///指定真机的IP，获取其methodChannel服务能力
const String _serverHost = '30.8.82.32';

void main() {
  runInMockTestEnvironment(_serverHost, () {
    autoGoldenTestWidget(const MyApp());
  });
}
