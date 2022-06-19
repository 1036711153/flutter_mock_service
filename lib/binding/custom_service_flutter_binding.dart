import 'package:flutter/material.dart' hide Action;
import 'package:flutter_mock_service/service/service_manager.dart';
import 'service_flutter_binding.dart';

///hook住flutter-channel服务
class CustomServiceFlutterBinding extends WidgetsFlutterBinding with ServiceFlutterBinding {
  //key == pluginName_methodName , Map<String,dynamic> == {'arguments':xxx}
  static final Map<String, Map<String, dynamic>> sIgnorePlugin = <String, Map<String, dynamic>>{};

  //key == pluginName_methodName
  static final Map<String, Map<String, dynamic>> sReplacePlugin = <String, Map<String, dynamic>>{};

  CustomServiceFlutterBinding() {
    isClient = true;
  }
}
