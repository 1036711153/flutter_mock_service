# flutter_mock_service

## 功能介绍
这种一种单元测试mock数据的框架，核心思路是使用CURL命令代替HTTP发送请求，使用flutter-test自带的截图对比方式比较结果

### 插件mock方式
* MOCK_HTTP: 使用网络服务实现真实请求数据
* MOCK_JSON: 使用本地JSON数据mock请求
* MOCK_JSON_HTTP_GENERATE：使用网络服务生成本地JSON数据，保证CI运行条件和结果一致性；

### 插件使用场景
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

### 原理介绍
Flutter Test运行环境下是无法发送真正的网络请求出去，核心原因是因为依赖的socket服务无法建立链接发送，因此
所有的网络请求都需要手动mockHttp数据，在AutomatedTestWidgetsFlutterBinding的实现类中有如下代码setupHttpOverrides
如果所有的网络请求通过此方式去mock成本很大，本插件自动帮助mock数据，并实现自动化检测方式；

```
  @override
  void initInstances() {
    super.initInstances();
    timeDilation = 1.0; // just in case the developer has artificially changed it for development
    if (overrideHttpClient) {
      binding.setupHttpOverrides();
    }
    ...
  }
```

插件使用CURL命令转发网络请求，HOOK住HttpClient和MethodChannel核心逻辑层

HOOK住HttpClient和核心逻辑代码在http_impl文件，核心代码如下：
```
      ///CURL
      String url = _currentUri!.toString();
      ContentType? type = request.headers.contentType;
      String contentTypeParams = '';
      if (type != null) {
        contentTypeParams = 'Content-Type:' + type.mimeType;
      }

      List<String> curlList = [
        '-H',
        contentTypeParams,
        '-X',
        method,
        '--data',
        requestParams,
        url,
      ];
```

HOOK住MethodChannel的核心逻辑代码在test_flutter_binding文件：

```
String getHttpResult(String params) {
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

其中MethodChannel依赖于一台真机，运行example工程后会执行 startFlutterMockService()去启动18888的ip网络服务代理转发真正的请求，
指定MOCK_JSON_HTTP_GENERATE方式运行后会自动生成mock_json文件；


### Next TO DO
此框架原理类似录制回放，mock数据生成本地json文件，以供下次运行作为输入， 使用截图对比自动化校验方式可保证输出的结果一致性；
但是由于mock的数据单一化，无法校验很多线上真实运行环境，如果可以使用CURL发网络请求到各家公司的真实日志采集数据平台上做MOCK
数据源理论上也可行，但此方式有一个比较大的问题是无法保证数据输入标准，导致运行结果不一致性；



