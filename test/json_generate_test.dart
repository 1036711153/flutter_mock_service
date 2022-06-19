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

const String _serverHost = '30.8.82.32';

void main() async {
  //使用CURL命令 curl -X GET https://www.baidu.com 代替发送请求数据
  runInMockTestEnvironment(_serverHost, () {
    testWidgets('widget test', (WidgetTester tester) async {
      await testGetHttp();
    });
  }, curlCommands: [
    '-X',
    'GET',
    'https://www.baidu.com',
  ], mockWay: MOCK_WAY.MOCK_JSON_HTTP_GENERATE);
}

Future<void> testGetHttp() async {
  final HttpClient client = HttpClient();
  final HttpClientRequest request = await client.getUrl(Uri.parse("https://www.baidu.com/"));
  final HttpClientResponse response = await request.close();
  response.transform(utf8.decoder).listen((contents) {
    print(contents);
  });
}
