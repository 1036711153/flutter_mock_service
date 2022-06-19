import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mock_service/service/service_manager.dart';
import 'dart:ui' as ui;
import 'custom_service_flutter_binding.dart';

mixin ServiceFlutterBinding on ServicesBinding {
  @override
  BinaryMessenger createBinaryMessenger() {
    // TODO: implement createBinaryMessenger
    return _DefaultBinaryMessenger._();
  }
}

class _DefaultBinaryMessenger extends BinaryMessenger {
  _DefaultBinaryMessenger._();

  MethodCodec codec = const StandardMethodCodec();

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    ui.channelBuffers.push(channel, data, (ByteData? data) {
      if (callback != null) callback(data);
    });
  }

  @override
  Future<ByteData?> send(String channel, ByteData? message) {
    try {
      final MethodCall call = codec.decodeMethodCall(message);
      //客户端端无插件则调用服务端插件执行
      final Map<dynamic, dynamic> clientParams = new Map<dynamic, dynamic>();
      clientParams['pluginName'] = channel;
      clientParams['methodName'] = call.method;
      clientParams['arguments'] = call.arguments;
      if (CustomServiceFlutterBinding.sReplacePlugin.containsKey(channel + '_' + call.method)) {
        Map<String, dynamic> argMap = CustomServiceFlutterBinding.sReplacePlugin[channel + '_' + call.method]!;
        if (call.arguments is Map) {
          Map map = call.arguments;
          map.forEach((key, value) {
            if (argMap.containsKey(value)) {
              Map replaceMap = argMap[value];
              channel = replaceMap['pluginName'];
              message = codec.encodeMethodCall(MethodCall(replaceMap['methodName'], replaceMap['arguments']));
            }
          });
        }
      }
    } catch (e) {}
    return _sendPlatformMessage(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      ui.channelBuffers.clearListener(channel);
    } else {
      ui.channelBuffers.setListener(channel, (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
        ByteData? response;
        try {
          response = await handler(data);
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'services library',
            context: ErrorDescription('during a platform message callback'),
          ));
        } finally {
          callback(response);
        }
      });
    }
  }

  Future<ByteData?> _sendPlatformMessage(String channel, ByteData? message) {
    final Completer<ByteData?> completer = Completer<ByteData?>();

    ui.window.sendPlatformMessage(channel, message, (ByteData? reply) {
      /// TODO FISH_TAG: START - MOD
      // try {
      //   completer.complete(reply);
      // } catch (exception, stack) {
      //   FlutterError.reportError(FlutterErrorDetails(
      //     exception: exception,
      //     stack: stack,
      //     library: 'services library',
      //     context: ErrorDescription(
      //         'during a platform message response callback'),
      //   ));
      // }

      if (reply == null) {
        if (isClient) {
          bool isJsonMethodCodec = true;
          try {
            MethodCall call = JSONMethodCodec().decodeMethodCall(message);
            if (call != null) {
              try {
                completer.complete(reply);
              } catch (exception, stack) {
                FlutterError.reportError(FlutterErrorDetails(
                  exception: exception,
                  stack: stack,
                  library: 'services library',
                  context: ErrorDescription('during a platform message response callback'),
                ));
              }
            }
          } catch (e) {
            isJsonMethodCodec = false;
          }

          if (isJsonMethodCodec) {
            return;
          }

          try {
            final MethodCall call = codec.decodeMethodCall(message);
            //客户端端无插件则调用服务端插件执行
            final Map<dynamic, dynamic> clientParams = new Map<dynamic, dynamic>();
            clientParams['pluginName'] = channel;
            clientParams['methodName'] = call.method;
            clientParams['arguments'] = call.arguments;

            Map<String, Map<String, dynamic>> ignorePlugin = CustomServiceFlutterBinding.sIgnorePlugin;
            if (ignorePlugin.containsKey(channel + '_' + call.method)) {
              Map<String, dynamic> channelParams = ignorePlugin[channel + '_' + call.method]!;
              if (channelParams['arguments'] == clientParams['arguments']) {
                completer.complete(codec.encodeSuccessEnvelope(null));
                return;
              } else {
                if (channelParams['arguments'] is Map && clientParams['arguments'] is Map) {
                  Map argsMap = channelParams['arguments'];
                  bool match = true;
                  argsMap.forEach((key, value) {
                    if (clientParams['arguments'][key] != null) {
                      if (value is List) {
                        match = match & (value.contains(clientParams['arguments'][key]));
                      } else {
                        match = match & (clientParams['arguments'][key] == value);
                      }
                    }
                  });
                  if (match) {
                    printLog('ignorePlugin clientParams  == $clientParams');
                    completer.complete(codec.encodeSuccessEnvelope(null));
                    return;
                  }
                }
              }
            }

            String params = const JsonCodec().encode(clientParams);
            getHttpDioResult(params).then((String? serverResponse) {
              if (serverResponse != null && serverResponse.isNotEmpty) {
                final Map<dynamic, dynamic> map = const JsonCodec().decode(serverResponse);
                if (map['success']) {
                  completer.complete(codec.encodeSuccessEnvelope(map['result']));
                } else {
                  throw Exception('Flutter Unit Test Server: params = $params, errorCode = ${map['errorCode']}, errorMsg = ${map['errorMsg']}');
                }
              } else {
                completer.complete(codec.encodeSuccessEnvelope(null));
              }
            }).timeout(Duration(milliseconds: 10000), onTimeout: () {
              completer.complete(codec.encodeSuccessEnvelope(null));
            });
          } catch (e) {
            print('sendPlatformMessage , error :${e.toString()}');
            FlutterError.reportError(FlutterErrorDetails(
              exception: 'sendPlatformMessage , error :${e.toString()} ',
              stack: null,
              library: 'services library',
              context: ErrorDescription('during a platform message response callback'),
            ));
          }
        } else {
          try {
            completer.complete(reply);
          } catch (exception, stack) {
            FlutterError.reportError(FlutterErrorDetails(
              exception: exception,
              stack: stack,
              library: 'services library',
              context: ErrorDescription('during a platform message response callback'),
            ));
          }
        }
      } else {
        try {
          completer.complete(reply);
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'services library',
            context: ErrorDescription('during a platform message response callback'),
          ));
        }
      }

      ///TODO FISH_TAG: END
    });
    return completer.future;
  }

  Future<String?> getHttpDioResult(String params) async {
    if (sMockWay == MOCK_WAY.MOCK_JSON) {
      if (sMockJsonPluginResult.containsKey(params)) {
        return sMockJsonPluginResult[params];
      }
    }
    int startTime = Timeline.now;
    int usePort = mockPortNum;
    Dio dio = Dio();
    dio.options.contentType = 'application/json';
    dio.options.connectTimeout = 60000;
    dio.options.receiveTimeout = 60000;
    dio.options.method = 'post';
    dio.options.baseUrl = 'http://$serverHost:$usePort';

    Response response = await dio.post('', data: '$params').catchError((e) {
      if (e.toString().contains('SocketException: OS Error:')) {
        errorCallBack?.call(e);
      }
    });
    String? result;
    if (response != null && response.statusCode == HttpStatus.ok) {
      String serverResponse = response.data;
      int dif = Timeline.now - startTime;
      if (dif >= 3000000) {
        printLog('Warning Process CostTime == $dif , params == $params');
      }
      printLog('usePort = $usePort , params  = $params , serverResponse = $serverResponse ');
      result = response.data;
    } else {
      result = null;
    }
    if (sMockWay == MOCK_WAY.MOCK_JSON_HTTP_GENERATE) {
      sMockJsonPluginResult[params] = result;
    }
    return result;
  }
}
