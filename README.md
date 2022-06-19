# flutter_mock_service


## 1. 核心功能
**插件核心诉求： 不想维护Flutter业务逻辑测试代码，甚至不想写Flutter测试用例逻辑；**
**插件核心功能： 一行代码自动化运行CI单测，MOCK数据方式保证输入一致，OCR截图对比方式保证输出验证一致；**
**插件核心卖点： Flutter Test的单元测试环境代替集成测试环境验证功能，无需整包构建，秒级运行结果；**

示例代码：
```
void main() {
  runInMockTestEnvironment(_serverHost, () {
    autoGoldenTestWidget(const MyApp());
  });
}
```
通过命令：flutter test --update-goldens --dart-define="mock_way=json_generate"
执行上面代码会自动生成本地mock_json文件，自动生成4张滚动不同位置的图片；其中生成的mock_json会作为标准输入源，4张图片会作为标准输出源通过OCR验证结果；

##  2.  背景介绍
CI单元测试，作为基础保障都知道其重要性，但是如果CI单测复杂，业务逻辑多，维护起来就是头大的事情；
传统测试方案有Unit单元测试 / 整包集成测试，客户端开发中一般单元测试交给开发，集成测试交给测试人员；
* 单元测试一般书写基本的输入输出，保证函数集/大函数集覆盖，其运行在源码阶段，无需出整包构建，运行速度在秒级；
* 集成测试方案大多数由整包构建完毕后，Driver驱动，OCR图片对比方式代替肉眼自动比对结果，因需整包构建+自动化模拟点击，耗时至少在10min+；



如果集成测试的任务可以在单元测试完成，那是不是开发测试集成效率可以大幅提升，Web端就可以做到，原因是有Chrome的浏览器运行环境，客户端无法实现是因为没有快速构建运行的沙盒环境；回头看Flutter Test 在单元测试阶段有哪些能力呢：
* Flutter 具有Unit Test / Widget Test 能力，其中Widget Test不需要构建整包即可有沙盒运行环境，可以检测一些Widget元素；
* Flutter Test 具有goldens 截图自动对比的OCR运行方式，可以代替人工检测；
* Flutter Test的Http/Method Channel服务能力，这快能力目前需手动MOCK，无法在沙盒环境中正常运行；


## 3. 关键问题

### 3.1 Http服务能力解决
如果想在单元测试阶段做集成测试阶段的活，目前来看Flutter就欠缺一个Http/Method Channel服务能力，若解决此问题可以将大量考虑使用单元测试环境代替集成测试环节的活；
flutterTest是可以运行一些Dart代码，但是httpClient运行到sky_engine的一些代码逻辑时候就没有返回值，导致无法发送一个http请求出去；因此需手动MOCK数据，参考mockito/flutter-test写法，如下模拟一段HTTP服务代码：
```
/// mock 模拟 http
class MockClient extends Mock implements http.Client {}
void main() {
    test("testHttp", () async {
      final client = MockClient();
      when(client.get("xxxx"))
          .thenAnswer((_) async {
        return http.Response(
            '{"title": "test title", "body": "test body"}', 200);
      });
      var post = await fetchPost(client);
      expect(post.title, "test title");
    });
```

如果针对茫茫http服务，估计是个人都想放弃，那有没有一种方式可以在Flutter Test沙盒环境下获取服务能力呢？是否有机制绕过去，还真有：偶然机会发现官方介绍Process，其通过Process.run可以实现一些shell命令；
![undefined](https://intranetproxy.alipay.com/skylark/lark/0/2021/png/293185/1634629281583-bc44ff1d-cf0e-4ee5-8b83-ad0d31f92311.png)

既然可以运行Shell命令，即可以通过Linux系统CURL/WGET方式发送一个http请求，在flutterTest环境中发送如下：
```
 test('httpTest', () async {
    ProcessResult result = await Process.run('curl', [
      'http://www.baidu.com',
    ]);
    String serverResponse = result.stdout();
  });
```
实际测试发现在flutterTest环境中运行在Process.run也卡住没有返回值，跟进分析代码发现同步方式Process.runSyn可以正常返回值：
![undefined](https://intranetproxy.alipay.com/skylark/lark/0/2021/png/293185/1634631102937-d849b860-9c93-4c41-b06e-521bf197bcb4.png)
于是http服务能力就可以通过shell命令curl绕过去执行；

### 3.2 Method Channel服务能力解决
很多公司考虑安全问题，不会使用HTTP服务，会通过Method Channel调用Native封装各家公司的网络服务发送请求，因此光解决HTTP服务问题还不够，那有没有什么方式解决Method Channel动态获取能力呢？这里推荐一种实现方式，将集成包APP开启一个IP端口作为Server，通过这个IP获取集成包运行环境下的各种MethodChannel能力，这样就解决Method Channel问题；

考虑Method Channel的HOOK方式需要修改Flutter源码，这里推荐使用HOOK Service的实现方式，Method Channel其核心能力在ServicesBinding中，我们可以mixin一个HttpFlutterBinding然后实现ServicesBinding相关能力，在CustomTestFlutterBinding去with对应的HttpFlutterBinding就可以Hook住想要的http服务端能力了；这块如果不了解其中原理可以好好研究Flutter的with Binding相关代码，示例代码如下：
```
///hook核心服务
class CustomTestFlutterBinding extends AutomatedTestWidgetsFlutterBinding with HttpFlutterBinding {
  ...
}

mixin HttpFlutterBinding on ServicesBinding {
  @override
  BinaryMessenger createBinaryMessenger() {
    // TODO: implement createBinaryMessenger
    return _DefaultBinaryMessenger._();
  }
}

class _DefaultBinaryMessenger extends BinaryMessenger {
  ...

  ByteData _sendPlatformMessage(String channel, ByteData message) {
    final MethodCall call = codec.decodeMethodCall(message);
    //客户端端无插件则调用服务端插件执行
    final Map<dynamic, dynamic> clientParams = new Map<dynamic, dynamic>();
    clientParams['pluginName'] = channel;
    clientParams['methodName'] = call.method;
    clientParams['arguments'] = call.arguments;
    clientParams['timeout'] = SocketConfig.serverCallMethodTimeOut;

    if (CustomTestFlutterBinding.ignoreResultPlugin.containsKey(clientParams['pluginName'])) {
      List<String> methods = CustomTestFlutterBinding.ignoreResultPlugin[clientParams['pluginName']];
      if (methods.contains(clientParams['methodName'])) {
        return codec.encodeSuccessEnvelope(null);
      }
    }

    ///curl -H "Content-Type:application/json" -X POST --data '{"message": "sunshine"}'  http://30.8.65.212:18888
    String params = const JsonCodec().encode(clientParams);
    var result = Process.runSync('curl', [
      '-H',
      "Content-Type:application/json",
      '-X',
      'POST',
      '--data',
      '$params',
      'http://$serverHost:18888',
    ]);
    String serverResponse = result.stdout;
    if (serverResponse != null && serverResponse.isNotEmpty) {
      final Map<dynamic, dynamic> map = const JsonCodec().decode(serverResponse);
      if (map['success']) {
        return codec.encodeSuccessEnvelope(map['result']);
      } else {
        throw Exception('errorCode ${map['errorCode']},errorMsg ${map['errorMsg']}');
      }
    } else {
      return codec.encodeSuccessEnvelope(null);
    }
  }
 ```

## 4. 插件介绍

解决上述问题后，介绍下本插件的核心功能特色点，插件原理类似录制回放，通过CURL和真机代理转发Method Channel打通HTTP/Method Channel服务能力，可以自动化将mock数据生成到本地json文件，以供下次运行作为标准输入， 使用截图对比自动化校验方式保证输出结果一致；

### 4.1 插件mock方式
插件支持3种运行方式，可根据自己的测试场景选择，比如不采用OCR作为标准检测结果可考虑使用MOCK_HTTP方式运行：
* MOCK_HTTP: 使用网络服务实现真实请求数据
* MOCK_JSON: 使用本地JSON数据mock请求
* MOCK_JSON_HTTP_GENERATE：使用网络服务生成本地JSON数据，保证CI运行条件和结果一致性；


### 4.2 插件使用场景
1. Mock NetWorkImage
   如果FlutterTest环境下出现 Image.network(xxx)会出现如下异常：

```
type 'Null' is not a subtype of type 'List<int>' in type cast

When the exception was thrown, this was the stack:
#1      _MockHttpResponse.drain (package:flutter_test/src/_binding_io.dart:364:22)
#2      NetworkImage._loadAsync (package:flutter/src/painting/_network_image_io.dart:99:24)
<asynchronous suspension>  
```
使用本插件包裹可以解决此异常，示例如下：

```
  runInMockTestEnvironment(_serverHost, () {
    testWidgets('widget test', (WidgetTester tester) async {
      Widget image = Image.network(
        'https://img.alicdn.com/imgextra/i3/O1CN01royvQd1pwhMbpkIs9_!!6000000005425-49-tps-144-144.webp',
      );
      await tester.pumpWidget(image, const Duration(milliseconds: 8000));
    }, mockWay: MOCK_WAY.MOCK_HTTP);
  });
```

2. Mock HTTP  Request
   一个HTTP GET/POST 请求发送出去是无返回数据结果的，主要原因是socket依赖问题，但是flutterTest可以运行CURL命令，
   因此网络请求可以通过CURL代替发送出去，使用方式如下

```
runInMockTestEnvironment(_serverHost, () {
    testWidgets('widget test', (WidgetTester tester) async {
      final HttpClient getClient = HttpClient();
      final HttpClientRequest getRequest = await getClient.getUrl(Uri.parse("https://www.baidu.com/"));
      final HttpClientResponse getResponse = await getRequest.close();
      getResponse.transform(utf8.decoder).listen((contents) {
        print(contents);
      });

      final HttpClient postClient = HttpClient();
      final HttpClientRequest postRequest = await postClient.postUrl(Uri.parse("https://jsonplaceholder.typicode.com/posts"));
      postRequest.headers.set(HttpHeaders.contentTypeHeader, "application/json; charset=UTF-8");
      postRequest.write('{"title": "Foo","body": "Bar", "userId": 99}');
      final HttpClientResponse postResponse = await postRequest.close();
      postResponse.transform(utf8.decoder).listen((contents) {
        print(contents);
      });
    });
  }, mockWay: MOCK_WAY.MOCK_HTTP);
```

另外如果插件拼接的CURL去mock的请求不满足要求，可以使用扩展的命令方法，如下案例：

```
  runInMockTestEnvironment(_serverHost, () {
    testWidgets('widget test', (WidgetTester tester) async {
      await testGetHttp();
    });
  }, curlCommands: [
    '-X',
    'GET',
    'https://www.baidu.com',
  ], mockWay: MOCK_WAY.MOCK_JSON_HTTP_GENERATE);
```

3. MOCK MethodChannel
   很多依赖的MethodChannel需要手动mock，这部分也是维护成本，本插件核心思路就是彻底解放MOCK数据，启动一个真机然后将
   真机作为网络服务端server,运行的CI环境执行Channel获取数据时会从启动的真机服务拿真正的数据结果：_serverHost是真机IP，

案例：
第一步运行example真机工程，第二步将_serverHost指定真机IP，如下代码就可以完美运行；

```
  runInMockTestEnvironment(_serverHost, () {
    testWidgets('widget test', (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel('flutter_mock_service');
      String platformVersion = await channel.invokeMethod('getPlatformVersion');
      print(platformVersion);
    });
  }, mockWay: MOCK_WAY.MOCK_JSON_HTTP_GENERATE);
```

4. auto goldens compare
   自动化图片对比，通过此插件可以自动化图片对比，代码如下，需要注意autoGodlenTest前面的await不要丢了；
   其会自动对比当前/下滑1500px/上滑800px/横滑600px等不同场景的图片，如果使用mock_json方式运行，可以保证
   每次运行的输入和输出都是一致；

```
  runInMockTestEnvironment(_serverHost, () {
     autoGoldenTestWidget(const MyApp());
  },  mockWay: MOCK_WAY.MOCK_JSON);
```   

首次生成mock_json文件和goldens图片，请将mockWay改为MOCK_JSON_HTTP_GENERATE，然后执行
flutter test --update-goldens
即可生成所依赖的外部条件
下次运行时候记得将mockWay改为MOCK_JSON，保证输入输出一致性；

5. 文字渲染异常
   内置NotoSansSC字体可正常渲染中文，若设置其他字体无法正常渲染，autoGoldenTestWidget函数内置MaterialApp的所有字体
   设置为NotoSansSC标准字体, 具体参考example案例的运行截图
```
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
```


### 4.3 核心代码
主要是runInMockTestEnvironment函数如下，主要初始化各种能力，包括HOOK Http/Method Channel等

```
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
```


真机开启一个IP服务能力关键代码
```
///初始化Mock Service
Future<void> initMockService() async {
  initPortMockService(mockPortNum);
  print('$FLUTTER_SERVICE_MANAGER_TAG init MockService');
}

///指定端口启动服务
Future<void> initPortMockService(int port) async {
  HttpServer.bind(InternetAddress.anyIPv6, port, shared: true).then((server) {
    server.listen((HttpRequest request) async {
      String method = request.method;
      Map<String, dynamic> result = Map<String, dynamic>();
      if (method == 'POST') {
        String value = await utf8.decoder.bind(request).join();
        print('$FLUTTER_SERVICE_MANAGER_TAG server receive clientParams: $value');
        try {
          final Map<dynamic, dynamic> map = const JsonCodec().decode(value);
          final String pluginName = map['pluginName'];
          final String methodName = map['methodName'];
          final dynamic arguments = map['arguments'];
          final int timeout = map['timeout'] ?? 3000;
          dynamic jsonData = '';
          jsonData = await handleMock(pluginName, methodName, arguments).timeout(Duration(milliseconds: timeout), onTimeout: () {
            result['success'] = true;
            result['result'] = null;
          }).catchError((e, trace) {
            print('$FLUTTER_SERVICE_MANAGER_TAG flutter methodChannel error :'
                ' ${e.toString()} ,trace : ${trace.toString()}');
            jsonData = ErrorTag.FLUTTER_METHOD_ERROR + ' , reason : ${e.toString()}';
          });
          result['success'] = true;
          result['result'] = jsonData;
        } catch (e) {
          result['success'] = false;
          result['errorCode'] = -1;
          result['errorMsg'] = ErrorTag.FLUTTER_METHOD_ERROR + ' , reason : ${e.toString()}';
        }
      } else {
        result['success'] = false;
        result['errorCode'] = -2;
        result['errorMsg'] = ErrorTag.FLUTTER_METHOD_ERROR + ' , reason : get http can not response';
      }

      String printJson = const JsonCodec().encode(result);
      request.response.write(printJson);
      request.response.close();
    });
  });
}

```

Flutter Test环境下获取真机IP服务转发能力关键代码

```
/// 通过HTTP获取到的数据
  String getHttpResult(String params) {
   ...
    ///curl -H "Content-Type:application/json" -X POST --data '{"message": "sunshine"}'  http://30.8.65.212:18888
    var result = Process.runSync('curl', [
      '-H',
      "Content-Type:application/json",
      '-X',
      'POST',
      '--data',
      params,
      'http://$serverHost:18888',
    ]);
    String serverResponse = result.stdout;
    ... 
    return serverResponse;
  }
```

图片自动化对比: 会执行首次渲染/上滑1500px/下滑800px/横滑600px等4种场景图片对比auto_compare标准图片
```
void autoGoldenTestWidget(Widget pageView) {
  testWidgets('widget test', (WidgetTester tester) async {
    ///规则屏幕尺寸1080*1920
    tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);

    Widget widget = generateMaterialAppRoot(pageView);

    ///首次渲染
    for (int i = 0; i < 20; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value1.png'));

    //上滑1500px
    final gesture = await tester.startGesture(const Offset(200, 300)); //Position of the scrollview
    await gesture.moveBy(const Offset(0, -1500));
    for (int i = 0; i < 20; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value2.png'));

    ///下滑800px
    await gesture.moveBy(const Offset(0, 800));
    for (int i = 0; i < 20; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value3.png'));

    ///横滑600px
    await gesture.moveBy(const Offset(-600, 0));
    for (int i = 0; i < 20; i++) {
      await tester.pumpWidget(widget, const Duration(milliseconds: 5000));
    }
    await expectLater(find.byKey(const ValueKey('autoGoldenTestCapturePoint')), matchesGoldenFile('auto_compare/value4.png'));
  });
}
```

### Next TO DO
此框架原理类似录制回放，mock数据生成本地json文件，以供下次运行作为输入， 使用截图对比自动化校验方式可保证输出的结果一致性；
但是由于mock的数据单一化，无法校验很多线上真实运行环境，如果可以使用CURL发网络请求到各家公司的真实日志采集数据平台上做MOCK
数据源理论上也可行，但此方式有一个比较大的问题是无法保证数据输入标准，导致运行结果不一致性；



