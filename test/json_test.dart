// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mock_service/flutter_mock_service.dart';
import 'package:flutter_test/flutter_test.dart';

///指定真机的IP，获取其methodChannel服务能力
const String _serverHost = '30.8.82.32';

void main() {
  runInMockTestEnvironment(_serverHost, () {
    testWidgets('widget test', (WidgetTester tester) async {
      await testImage(tester);
      await testGetHttp();
      await testPostHttp();
      await testMethodChannel();
    });
  }, mockWay: MOCK_WAY.MOCK_JSON);
}

Future<void> testMethodChannel() async {
  const MethodChannel channel = MethodChannel('flutter_mock_service');
  String platformVersion = await channel.invokeMethod('getPlatformVersion');
  print(platformVersion);
}

Future<void> testImage(WidgetTester tester) async {
  Widget image = Image.network(
    'https://img.alicdn.com/imgextra/i3/O1CN01royvQd1pwhMbpkIs9_!!6000000005425-49-tps-144-144.webp',
    height: 100,
    width: 100,
  );
  Widget widget = MaterialApp(
    key: const ValueKey('CapturePoint'),
    title: '1',
    home: image,
  );

  ///首次渲染
  for (int i = 0; i < 10; i++) {
    await tester.pumpWidget(widget, const Duration(milliseconds: 8000));
  }
}

Future<void> testGetHttp() async {
  final HttpClient client = HttpClient();
  final HttpClientRequest request = await client.getUrl(Uri.parse("https://www.baidu.com/"));
  final HttpClientResponse response = await request.close();
  response.transform(utf8.decoder).listen((contents) {
    print(contents);
  });
}

Future<void> testPostHttp() async {
  final HttpClient client = HttpClient();
  final HttpClientRequest request = await client.postUrl(Uri.parse("https://jsonplaceholder.typicode.com/posts"));
  request.headers.set(HttpHeaders.contentTypeHeader, "application/json; charset=UTF-8");
  request.write('{"title": "Foo","body": "Bar", "userId": 99}');
  final HttpClientResponse response = await request.close();
  response.transform(utf8.decoder).listen((contents) {
    print(contents);
  });
}
