import 'dart:async';
import 'dart:io';

import 'package:devalay/core/api.dart';
import 'package:devalay/core/firebase.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('network failures are not counted as crashes', () {
    final opts = RequestOptions(path: '/deities');
    expect(isNetworkFailure(ApiException('Could not reach Devalay.')), isTrue);
    expect(isNetworkFailure(const SocketException('Failed host lookup')), isTrue);
    expect(isNetworkFailure(const HttpException('Connection aborted')), isTrue);
    expect(isNetworkFailure(TimeoutException('slow')), isTrue);
    expect(isNetworkFailure(DioException(requestOptions: opts, type: DioExceptionType.connectionError)), isTrue);
    expect(isNetworkFailure(DioException(requestOptions: opts, type: DioExceptionType.receiveTimeout)), isTrue);
    // The image cache (package:http) on a phone that lost its connection, as seen from 1.5.4.
    expect(
      isNetworkFailure(
        http.ClientException(
          "SocketException: Failed host lookup: 'upload.wikimedia.org'",
          Uri.parse('https://upload.wikimedia.org/wikipedia/commons/x.jpg'),
        ),
      ),
      isTrue,
    );
  });

  test('real bugs and server errors still count', () {
    final opts = RequestOptions(path: '/deities');
    expect(isNetworkFailure(ApiException('Server error', status: 500)), isFalse);
    expect(isNetworkFailure(DioException(requestOptions: opts, type: DioExceptionType.badResponse)), isFalse);
    expect(isNetworkFailure(StateError('bad state')), isFalse);
    expect(isNetworkFailure(TypeError()), isFalse);
    expect(isNetworkFailure(const FormatException('bad json')), isFalse);
  });
}
