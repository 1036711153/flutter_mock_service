import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mock_service/flutter_mock_service.dart';
import 'package:flutter_mock_service/service/service_manager.dart';
import 'dart:ui' as ui;
import 'custom_test_flutter_binding.dart';
import 'package:flutter_test/flutter_test.dart';

mixin TestFlutterBinding on BindingBase, ServicesBinding {
  @override
  void initInstances() {
    // TODO: implement initInstances
    super.initInstances();
  }

  @override
  TestDefaultBinaryMessenger createBinaryMessenger() {
    return CustomTestDefaultBinaryMessenger(_DefaultBinaryMessenger._());
  }
}

class CustomTestDefaultBinaryMessenger extends TestDefaultBinaryMessenger {
  CustomTestDefaultBinaryMessenger(this.delegate)
      : assert(delegate != null),
        super(delegate);

  /// The delegate [BinaryMessenger].
  final BinaryMessenger delegate;

  // The handlers for messages from the engine (including fake
  // messages sent by handlePlatformMessage).
  final Map<String, MessageHandler> _inboundHandlers = <String, MessageHandler>{};

  @override
  Future<ByteData?> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) {
    Future<ByteData?>? result;
    if (_inboundHandlers.containsKey(channel)) result = _inboundHandlers[channel]!(data);
    result ??= Future<ByteData?>.value(null);
    if (callback != null)
      result = result.then((ByteData? result) {
        callback(result);
        return result;
      });
    return result;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      _inboundHandlers.remove(channel);
      delegate.setMessageHandler(channel, null);
    } else {
      _inboundHandlers[channel] = handler; // used to handle fake messages sent via handlePlatformMessage
      delegate.setMessageHandler(channel, handler); // used to handle real messages from the engine
    }
  }

  final List<Future<ByteData?>> _pendingMessages = <Future<ByteData?>>[];

  /// The number of incomplete/pending calls sent to the platform channels.
  int get pendingMessageCount => _pendingMessages.length;

  // Handlers that intercept and respond to outgoing messages,
  // pretending to be the platform.
  final Map<String, MessageHandler> _outboundHandlers = <String, MessageHandler>{};

  // The outbound callbacks that were actually registered, so that we
  // can implement the [checkMockMessageHandler] method.
  final Map<String, Object> _outboundHandlerIdentities = <String, Object>{};

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    Future<ByteData?>? resultFuture;
    final MessageHandler? handler = _outboundHandlers[channel];
    if (handler != null) {
      resultFuture = handler(message);
    } else {
      resultFuture = delegate.send(channel, message);
    }
    if (resultFuture != null) {
      _pendingMessages.add(resultFuture);
      resultFuture.catchError((Object error) {
        /* errors are the responsibility of the caller */
      }).whenComplete(() => _pendingMessages.remove(resultFuture));
    }
    return resultFuture;
  }

  Future<void> get platformMessagesFinished {
    return Future.wait<void>(_pendingMessages);
  }

  void setMockMessageHandler(String channel, MessageHandler? handler, [Object? identity]) {
    if (handler == null) {
      _outboundHandlers.remove(channel);
      _outboundHandlerIdentities.remove(channel);
    } else {
      identity ??= handler;
      _outboundHandlers[channel] = handler;
      _outboundHandlerIdentities[channel] = identity;
    }
  }

  void setMockDecodedMessageHandler<T>(BasicMessageChannel<T> channel, Future<T> Function(T? message)? handler) {
    if (handler == null) {
      setMockMessageHandler(channel.name, null);
      return;
    }
    setMockMessageHandler(channel.name, (ByteData? message) async {
      return channel.codec.encodeMessage(await handler(channel.codec.decodeMessage(message)));
    }, handler);
  }

  void setMockMethodCallHandler(MethodChannel channel, Future<Object?>? Function(MethodCall message)? handler) {
    if (handler == null) {
      setMockMessageHandler(channel.name, null);
      return;
    }
    setMockMessageHandler(channel.name, (ByteData? message) async {
      final MethodCall call = channel.codec.decodeMethodCall(message);
      Object? object = await handler(call);
      if (object == null) {
        return delegate.send(channel.name, message);
      }
      try {
        return channel.codec.encodeSuccessEnvelope(await handler(call));
      } on PlatformException catch (error) {
        return channel.codec.encodeErrorEnvelope(
          code: error.code,
          message: error.message,
          details: error.details,
        );
      } on MissingPluginException {
        return null;
      } catch (error) {
        return channel.codec.encodeErrorEnvelope(code: 'error', message: '$error', details: null);
      }
    }, handler);
  }

  bool checkMockMessageHandler(String channel, Object? handler) => _outboundHandlerIdentities[channel] == handler;
}

class _DefaultBinaryMessenger extends BinaryMessenger {
  _DefaultBinaryMessenger._();

  MethodCodec codec = const StandardMethodCodec();

  // Handlers for incoming messages from platform plugins.
  // This is static so that this class can have a const constructor.
  static final Map<String, MessageHandler> _handlers = <String, MessageHandler>{};

  // Mock handlers that intercept and respond to outgoing messages.
  // This is static so that this class can have a const constructor.
  static final Map<String, MessageHandler> _mockHandlers = <String, MessageHandler>{};

  ByteData? _sendPlatformMessage(String channel, ByteData? message) {
    MethodCall call;
    try {
      call = codec.decodeMethodCall(message);
    } catch (e) {
      return null;
    }

    //客户端端无插件则调用服务端插件执行
    final Map<dynamic, dynamic> clientParams = new Map<dynamic, dynamic>();
    clientParams['pluginName'] = channel;
    clientParams['methodName'] = call.method;
    clientParams['arguments'] = call.arguments;
    clientParams['timeout'] = ServiceConfig.serverCallMethodTimeOut;

    if (CustomTestFlutterBinding.sIgnorePluginResult.containsKey(clientParams['pluginName'])) {
      List<String> methods = CustomTestFlutterBinding.sIgnorePluginResult[clientParams['pluginName']]!;
      if (methods.contains(clientParams['methodName'])) {
        return codec.encodeSuccessEnvelope(null);
      }
    }
    String params = const JsonCodec().encode(clientParams);
    String? serverResponse;
    switch (sMockWay) {
      case MOCK_WAY.MOCK_HTTP:
        serverResponse = getHttpResult(params);
        break;
      case MOCK_WAY.MOCK_JSON:
        serverResponse = getMockJsonResult(params);
        break;
      case MOCK_WAY.MOCK_JSON_HTTP_GENERATE:
        if (!sMockJsonPluginResult.containsKey(params)) {
          serverResponse = getHttpResult(params);
          setMockJsonResult(params, serverResponse);
        } else {
          serverResponse = sMockJsonPluginResult[params];
        }
        break;
    }

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

  /// 通过HTTP获取到的数据
  String getHttpResult(String params) {
    int startTime = Timeline.now;

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

    int dif = Timeline.now - startTime;

    if (dif / 1000 >= 3000) {
      printLog('Warning Process CostTime == $dif , params == $params');
    }
    return serverResponse;
  }

  String? getMockJsonResult(String params) {
    if (sMockJsonPluginResult.containsKey(params)) {
      return sMockJsonPluginResult[params];
    }
    return null;
  }

  void setMockJsonResult(String params, String serverResponse) {
    sMockJsonPluginResult[params] = serverResponse;
  }

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    ByteData? response;
    try {
      final MessageHandler? handler = _handlers[channel];
      if (handler != null) {
        response = await handler(data);
      } else {
        ui.channelBuffers.push(channel, data, callback!);
        callback = null;
      }
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'services library',
        context: ErrorDescription('during a platform message callback'),
      ));
    } finally {
      if (callback != null) {
        callback(response);
      }
    }
  }

  @override
  Future<ByteData?> send(String channel, ByteData? message) async {
    final MessageHandler? handler = _mockHandlers[channel];
    if (handler != null) return handler(message);
    return _sendPlatformMessage(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null)
      _handlers.remove(channel);
    else
      _handlers[channel] = handler;
    ui.channelBuffers.drain(channel, (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
      await handlePlatformMessage(channel, data, callback);
    });
  }
}
