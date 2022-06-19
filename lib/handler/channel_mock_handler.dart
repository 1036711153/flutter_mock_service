import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_mock_service/service/service_manager.dart';

typedef ChannelMockHandler = Future<dynamic> Function(String moduleName, String methodName, Map<dynamic, dynamic> arguments);

final Map<String, bool> _testResult = <String, bool>{};

///标记命中测试
void markHitMockResult(String tag, [bool result = true]) {
  _testResult[tag] = result;
}

///检测测试结果
bool testMockResult(String tag) {
  return _testResult[tag] ?? false;
}

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

final Map<String, ChannelMockHandler> channelMockHandlers = Map<String, ChannelMockHandler>();

///外部注册ChannelMock处理结果
void resisterChannelMockHandler(String handlerName, ChannelMockHandler handler) {
  channelMockHandlers[handlerName] = handler;
}

Future<dynamic> handleMock(String moduleName, String methodName, dynamic arguments) async {
  String handlerName = moduleName + '_' + methodName;
  if (channelMockHandlers.containsKey(handlerName)) {
    ///外部注册的情况处理
    ChannelMockHandler? handler = channelMockHandlers[handlerName];
    if (handler != null) {
      return handler.call(moduleName, methodName, arguments);
    }
  } else {
    ///使用本机的Channel处理
    final MethodChannel _channel = MethodChannel(moduleName);
    dynamic jsonData = await _channel.invokeMethod<dynamic>(methodName, arguments);
    return jsonData;
  }
  return null;
}
