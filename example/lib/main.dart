import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_mock_service/flutter_mock_service.dart';

import 'app_demo.dart';

void main() {
  ///启动主工程服务
  startFlutterMockService();
  runApp(const MaterialApp(
    home: MyApp(),
  ));
}
