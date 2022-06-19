import '../flutter_mock_service.dart';

/// MOCK_JSON 是通过本地JSON文件的注入Plugin Channel数据
/// MOCK_HTTP 是通过真机代理网络请求注入Plugin Channel数据
/// MOCK_JSON_GENERATE 利用HTTP真机的数据自动生产MOCK_JSON文件，文件存储test测试目录下
enum MOCK_WAY { MOCK_JSON, MOCK_HTTP, MOCK_JSON_HTTP_GENERATE }

MOCK_WAY sMockWay = MOCK_WAY.MOCK_JSON;

final Map<String, dynamic> sMockJsonPluginResult = <String, dynamic>{};

typedef ServiceErrorCallback = void Function(dynamic e);

const String FLUTTER_SERVICE_MANAGER_TAG = 'ServiceManager : ';

//ip 地址
String serverHost = '';

//Mock的端口号
int mockPortNum = 18888;

//是否客户端的标记位
bool isClient = false;

//控制日志打印标记位
bool showMockLog = true;

//回调方法
ServiceErrorCallback? errorCallBack;

class ErrorTag {
  static const String FLUTTER_METHOD_ERROR = 'FlutterMethodChanelError';
}

class ServiceConfig {
  ///server端callMethod的限制timeOut
  static int serverCallMethodTimeOut = 3000;
}

void startFlutterMockService() {
  initMockService();
}

void printLog(dynamic msg) {
  if (!showMockLog) {
    return;
  }
  print('$FLUTTER_SERVICE_MANAGER_TAG : $msg');
}

List<String>? sCurlCommands = [];

void registerCurlCommands(List<String>? curlCommands) {
  sCurlCommands = curlCommands;
}
