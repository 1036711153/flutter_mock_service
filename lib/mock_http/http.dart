// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mock_http;

import 'dart:async';
import 'dart:collection' show HashMap, HashSet, Queue, ListQueue, LinkedList, LinkedListEntry, UnmodifiableMapView;
import 'dart:convert';
import 'dart:developer' hide log;
import 'dart:isolate' show Isolate;
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_mock_service/flutter_mock_service.dart';

part 'crypto.dart';

part 'http_date.dart';

part 'http_headers.dart';

part 'http_impl.dart';

part 'http_parser.dart';

part 'http_session.dart';

void setupMockHttpOverrides() {
  HttpOverrides.global = MockHttpOverrides();
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? _) {
    return MockHttpClient(_);
  }
}
