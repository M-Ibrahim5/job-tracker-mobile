import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/app/theme/app_theme.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';

/// Wraps [child] in a themed `MaterialApp` without network fonts.
Widget testApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light(useGoogleFonts: false)
          : AppTheme.dark(useGoogleFonts: false),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: c!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// Overrides that select the fake backend with no latency.
List<Override> fakeOverrides([FakeBackend? backend]) => [
  useFakeBackendProvider.overrideWithValue(true),
  fakeBackendProvider.overrideWithValue(
    backend ?? FakeBackend(latency: Duration.zero),
  ),
];

/// [HttpClientAdapter] that answers from a closure.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON response body.
ResponseBody jsonBody(String json, int status) => ResponseBody.fromString(
  json,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
