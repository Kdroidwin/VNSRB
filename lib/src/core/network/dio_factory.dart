// ignore_for_file: constant_identifier_names

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/_constants.dart';

part 'dio_factory.g.dart';

/// Dio with basic configurations.
class DioFactory {
  static Dio produce() {
    final Dio dio = Dio();

    dio.options = BaseOptions(
      followRedirects: false,
      maxRedirects: 0,
      headers: {
        NetConsts.CONTENT_TYPE: NetConsts.APPLICATION_JSON,
        NetConsts.ACCEPT: NetConsts.APPLICATION_JSON,
      },
      contentType: NetConsts.APPLICATION_JSON,
      receiveTimeout: const Duration(milliseconds: NetConsts.API_TIMEOUT),
      sendTimeout: const Duration(milliseconds: NetConsts.API_TIMEOUT),
      connectTimeout: const Duration(milliseconds: NetConsts.API_TIMEOUT),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final uri = options.uri;
          if (uri.scheme.toLowerCase() != 'https' ||
              !NetConsts.TRUSTED_HTTPS_HOSTS.contains(uri.host.toLowerCase()) ||
              uri.port != 443 ||
              uri.userInfo.isNotEmpty) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                message: 'Blocked an untrusted network destination.',
              ),
            );
            return;
          }
          handler.next(options);
        },
      ),
    );

    // If not in release mode, log network requests with dio
    if (!kReleaseMode) {
      // dio.interceptors.add(
      //   PrettyDioLogger(requestHeader: true, requestBody: true, responseHeader: true),
      // );
    }

    return dio;
  }
}

@riverpod
Dio dio(Ref ref) => DioFactory.produce();
