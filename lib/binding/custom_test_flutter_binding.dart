import 'dart:convert';
import 'dart:io';

import 'package:flutter_mock_service/service/service_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_flutter_binding.dart';
import 'package:stack_trace/stack_trace.dart';

///hook核心channel服务,使用场景主要CI-Test场景
class CustomTestFlutterBinding extends AutomatedTestWidgetsFlutterBinding with TestFlutterBinding {
  ///key  is pluginName , List<String> is methodList
  static final Map<String, List<String>> sIgnorePluginResult = <String, List<String>>{};

  static String? _sRunFileName;
  static bool hasInit = false;

  CustomTestFlutterBinding() {
    isClient = true;
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  static Future<void> initEvn(String ip, {MOCK_WAY mockWay = MOCK_WAY.MOCK_HTTP}) async {
    sMockWay = mockWay;
    serverHost = ip;
    getFileNamePath();
    if (hasInit) {
      return;
    }
    hasInit = true;
    CustomTestFlutterBinding();
    //加载一些数据到sMockJsonPluginResult去mock plugin channel数据
    if (sMockWay == MOCK_WAY.MOCK_JSON) {
      await readMockJsonIntoPluginResult();
    }
  }

  static Future<void> disposeEvn() async {
    //针对MOCK_JSON_GENERATE方式要将sMockJsonPluginResult值写入到mock json file中
    if (sMockWay == MOCK_WAY.MOCK_JSON_HTTP_GENERATE) {
      await writePluginResultIntoMockJson();
    }
  }

  static Future<void> readMockJsonIntoPluginResult() async {
    String mockFile = CustomTestFlutterBinding.getMockJsonFilePath();
    File(mockFile).createSync(recursive: true);
    String mockJson = File(mockFile).readAsStringSync();
    if (mockJson.isNotEmpty) {
      final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(json.decode(mockJson));
      sMockJsonPluginResult.addAll(jsonMap);
    }
  }

  static Future<void> writePluginResultIntoMockJson() async {
    String mockFile = CustomTestFlutterBinding.getMockJsonFilePath();
    File(mockFile).createSync(recursive: true);
    File(mockFile).deleteSync(recursive: true);

    ///重新写入
    File(mockFile).createSync(recursive: true);
    Map<String, dynamic> result = sMockJsonPluginResult;
    File(mockFile).writeAsStringSync(json.encode(result));
  }

  static String getMockJsonFilePath() {
    final String fileNamePath = getFileNamePath();
    final List<String> split = fileNamePath.split('/');
    final String fileName = split[split.length - 1];
    final String mockJsonName = fileName.replaceAll('.dart', '_mock.json');
    String mockFilePath = fileNamePath.substring(0, fileNamePath.lastIndexOf('/')) + '/mock_json/$mockJsonName';
    return mockFilePath;
  }

  static String getFileNamePath() {
    if (_sRunFileName != null) {
      return _sRunFileName!;
    }
    List<Frame> frames = Trace.current().frames;
    for (Frame frame in frames) {
      if (frame.member == 'main') {
        _sRunFileName = frame.uri.path;
        return _sRunFileName!;
      }
    }
    return '';
  }
}
