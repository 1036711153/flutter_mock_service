import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

const MethodChannel channel = MethodChannel('flutter_mock_service');

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _getHttpResult = 'Unknown';
  String _postHttpResult = 'Unknown';

  @override
  void initState() {
    super.initState();
    postHttpUrl();
    getMethodChannel();
    getHttpUrl();
  }

  void getHttpUrl() async {
    final HttpClient client = HttpClient();
    final HttpClientRequest request = await client.getUrl(Uri.parse("https://www.baidu.com/"));
    final HttpClientResponse response = await request.close();
    response.transform(utf8.decoder).listen((contents) {
      _getHttpResult = contents;
      if (mounted) {
        setState(() {});
      }
    });
  }

  void postHttpUrl() async {
    final HttpClient client = HttpClient();
    final HttpClientRequest request = await client.postUrl(Uri.parse("https://jsonplaceholder.typicode.com/posts"));
    request.headers.set(HttpHeaders.contentTypeHeader, "application/json; charset=UTF-8");
    request.write('{"title": "Foo","body": "Bar", "userId": 99}');
    final HttpClientResponse response = await request.close();
    response.transform(utf8.decoder).listen((contents) {
      _postHttpResult = contents;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> getMethodChannel() async {
    String platformVersion = await channel.invokeMethod('getPlatformVersion');
    if (mounted) {
      setState(() {
        _platformVersion = platformVersion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Center(
        child: ListView.builder(
          key: Key('ListViewKey'),
          itemBuilder: (_, index) {
            if (index % 3 == 0) {
              return Container(
                color: Colors.red,
                margin: const EdgeInsets.all(12),
                child: Text('_platformVersion : $_platformVersion'),
              );
            }
            if (index % 3 == 1) {
              return Container(
                color: Colors.yellow,
                margin: const EdgeInsets.all(12),
                child: Text(
                  '_getHttpResult : $_getHttpResult',
                  maxLines: 8,
                ),
              );
            }
            return Container(
              color: Colors.greenAccent,
              margin: const EdgeInsets.all(12),
              child: Text(
                '_postHttpResult : $_postHttpResult',
                maxLines: 6,
              ),
            );
          },
          itemCount: 100,
        ),
      ),
    );
  }
}
