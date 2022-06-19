import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mock_service/flutter_mock_service.dart';
import 'package:flutter_mock_service/service/service_manager.dart';
import 'package:flutter_test/flutter_test.dart';

///根据--dart-define="mock_way=xxx"获取运行环境
MOCK_WAY getMockWay() {
  const String mockWayConfig = String.fromEnvironment('mock_way', defaultValue: 'json');
  if (mockWayConfig == 'http') return MOCK_WAY.MOCK_HTTP;
  if (mockWayConfig == 'json_generate') return MOCK_WAY.MOCK_JSON_HTTP_GENERATE;
  return MOCK_WAY.MOCK_JSON;
}

///加载渲染字体
Future<void> loadAppFonts() async {
  final fontManifest = await rootBundle.loadStructuredData<Iterable<dynamic>>(
    'FontManifest.json',
    (string) async => json.decode(string),
  );
  for (final Map<String, dynamic> font in fontManifest) {
    String fontStr = _derivedFontFamily(font);
    final fontLoader = FontLoader(fontStr);
    for (final Map<String, dynamic> fontType in font['fonts']) {
      fontLoader.addFont(rootBundle.load(fontType['asset']));
    }
    await fontLoader.load();
  }
}

String _derivedFontFamily(Map<String, dynamic> fontDefinition) {
  if (!fontDefinition.containsKey('family')) {
    return '';
  }
  final String fontFamily = fontDefinition['family'];
  if (fontFamily.startsWith('packages/')) {
    final fontFamilyName = fontFamily.split('/').last;
    if (['NotoSansSC'].any((font) => font == fontFamilyName)) {
      return fontFamilyName;
    }
  }
  return fontFamily;
}

///运行在mock环境下Test用例检测
R runInMockTestEnvironment<R>(String serverIp, R Function() body, {List<String>? curlCommands, MOCK_WAY? mockWay}) {
  ///如果未指定使用运行参数解析--dart-define="mock_way=json_generate"
  mockWay ??= getMockWay();

  ///初始化服务机器ip,mock方式
  CustomTestFlutterBinding.initEvn(serverIp, mockWay: mockWay);

  loadAppFonts();

  ///释放时生成mock-json文件
  tearDown(() {
    CustomTestFlutterBinding.disposeEvn();
  });

  ///外部注册curl命令
  registerCurlCommands(curlCommands);

  ///全局设置httpOverrides，替换flutter-test中MockHttpOverrides
  setupMockHttpOverrides();
  return body.call();
}

/// 使用generateMaterialAppRoot包裹根节点，切记不要pageView里面在有MaterialApp包裹
/// 主要解决的是统一字体设置为NotoSansSC保证能渲染字体，另外字体如果设置了其他样式字体也无法保证正常截图渲染
Widget generateMaterialAppRoot(Widget pageView) {
  return MaterialApp(
    key: const ValueKey('autoGoldenTestCapturePoint'),
    theme: ThemeData(
        textTheme: const TextTheme(
      headline1: TextStyle(fontFamily: 'NotoSansSC'),
      headline2: TextStyle(fontFamily: 'NotoSansSC'),
      headline3: TextStyle(fontFamily: 'NotoSansSC'),
      headline4: TextStyle(fontFamily: 'NotoSansSC'),
      headline5: TextStyle(fontFamily: 'NotoSansSC'),
      headline6: TextStyle(fontFamily: 'NotoSansSC'),
      subtitle1: TextStyle(fontFamily: 'NotoSansSC'),
      subtitle2: TextStyle(fontFamily: 'NotoSansSC'),
      bodyText1: TextStyle(fontFamily: 'NotoSansSC'),
      bodyText2: TextStyle(fontFamily: 'NotoSansSC'),
      caption: TextStyle(fontFamily: 'NotoSansSC'),
      button: TextStyle(fontFamily: 'NotoSansSC'),
      overline: TextStyle(fontFamily: 'NotoSansSC'),
    )),
    home: pageView,
  );
}

/// firstDumpTimes : widget首次渲染时候需要dump次数，由于有些业务复杂，需要多次dump才可以加载出页面元素
/// dumpTimes : 上下滑动后需要dump的次数，同理部分业务需网络加载，可能需多次dump
/// size : 屏幕截图尺寸
/// upScroll : 向上滑动距离
/// downScroll : 向下滑动距离
/// leftScroll : 向左滑动距离
void autoGoldenTestWidget(
  Widget pageView, {
  int firstDumpTimes = 20,
  int dumpTimes = 20,
  Size pageSize = const Size(1080, 1920),
  upScroll = 1500,
  downScroll = 800,
  leftScroll = 600,
}) {
  testWidgets('widget test', (WidgetTester tester) async {
    ///规则屏幕尺寸默认值为1080*1920
    tester.binding.window.physicalSizeTestValue = pageSize;

    Widget widget = generateMaterialAppRoot(pageView);

    ///首次渲染
    for (int i = 0; i < firstDumpTimes; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value1.png'));

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(Offset(0, -upScroll));
    for (int i = 0; i < dumpTimes; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value2.png'));

    await gesture.moveBy(Offset(0, downScroll));
    for (int i = 0; i < dumpTimes; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value3.png'));

    await gesture.moveBy(Offset(-leftScroll, 0));
    for (int i = 0; i < dumpTimes; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value4.png'));
  });
}
