// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'package:flutter_mock_service/flutter_mock_service.dart';
import 'package:flutter_mock_service_example/list_demo.dart';

const String _serverHost = '30.8.82.32';

void main() {
  runInMockTestEnvironment(_serverHost, () {
    autoGoldenTestWidget(const ListDemo());
  });
}
