import 'dart:convert';
import 'dart:io';

import 'package:restio/src/cache/cache_response_body.dart';
import 'package:restio/src/cache/snapshot.dart';
import 'package:restio/src/compression_type.dart';
import 'package:restio/src/headers.dart';
import 'package:restio/src/helpers.dart';
import 'package:restio/src/media_type.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

class Entry {
  final String url;
  final String requestMethod;
  final Headers varyHeaders;
  final int code;
  final String message;
  final Headers responseHeaders;
  final int sentRequestMillis;
  final int receivedResponseMillis;

  Entry(
    this.url,
    this.requestMethod,
    this.varyHeaders,
    this.code,
    this.message,
    this.responseHeaders,
    this.sentRequestMillis,
    this.receivedResponseMillis,
  );

  static const String _sentMillis = 'Restio-Sent-Millis';
  static const String _receivedMillis = 'Restio-Received-Millis';

  List<int> metaData() {
    final builder = StringBuffer();

    builder.writeln(url);
    builder.writeln(requestMethod);
    builder.writeln(varyHeaders.length);

    for (var i = 0; i < varyHeaders.length; i++) {
      builder.writeln('${varyHeaders.nameAt(i)}: ${varyHeaders.valueAt(i)}');
    }

    builder.writeln('$code $message');

    builder.writeln(responseHeaders.length + 2);

    for (var i = 0; i < responseHeaders.length; i++) {
      builder.writeln(
          '${responseHeaders.nameAt(i)}: ${responseHeaders.valueAt(i)}');
    }

    builder.writeln('$_sentMillis: $sentRequestMillis');
    builder.writeln('$_receivedMillis: $receivedResponseMillis');

    return utf8.encode(builder.toString());
  }

  Response response(Snapshot snapshot) {
    final contentTypeString =
        responseHeaders.value(HttpHeaders.contentTypeHeader);

    final contentType =
        contentTypeString != null ? MediaType.parse(contentTypeString) : null;

    final contentLengthString =
        responseHeaders.value(HttpHeaders.contentLengthHeader);

    final contentLength = contentLengthString != null
        ? (int.tryParse(contentLengthString) ?? -1)
        : -1;

    final compressionType = parseContentEncoding(
        responseHeaders.first(HttpHeaders.contentEncodingHeader));

    final cacheRequest = Request(
      uri: Uri.parse(url),
      method: requestMethod,
      headers: varyHeaders,
    );

    final spentMilliseconds = receivedResponseMillis - sentRequestMillis;

    return Response(
      originalRequest: cacheRequest,
      request: cacheRequest,
      code: code,
      message: message,
      headers: responseHeaders,
      sentAt: DateTime.fromMillisecondsSinceEpoch(sentRequestMillis),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedResponseMillis),
      spentMilliseconds: spentMilliseconds,
      totalMilliseconds: spentMilliseconds,
      body: CacheResponseBody(
        snapshot,
        contentType: contentType,
        contentLength: contentLength,
        compressionType: compressionType,
      ),
    );
  }

  bool matches(
    Request request,
    Response response,
  ) {
    return url == request.uriWithQueries.toString() &&
        requestMethod == request.method &&
        varyMatches(response, varyHeaders, request);
  }

  static bool varyMatches(
    Response cachedResponse,
    Headers cachedRequest,
    Request newRequest,
  ) {
    return !cachedResponse.headers.vary().any((item) {
      return cachedRequest.first(item) != newRequest.headers.first(item);
    });
  }

  static Future<Entry> sourceEntry(Stream<List<int>> source) async {
    final lines = await readAsBytes(source).then((bytes) {
      return utf8.decode(bytes);
    }).then(const LineSplitter().convert);

    var cursor = 0;
    final url = lines[cursor++];
    final requestMethod = lines[cursor++];
    final varyHeadersBuilder = HeadersBuilder();
    final varyRequestHeaderLineCount = int.tryParse(lines[cursor++]);

    for (var i = 0; i < varyRequestHeaderLineCount; i++) {
      varyHeadersBuilder.addLine(lines[cursor++]);
    }

    final varyHeaders = varyHeadersBuilder.build();

    final statusLine = lines[cursor++];
    if (statusLine == null || statusLine.length < 3) {
      throw Exception('Unexpected status line: $statusLine');
    }

    final code = int.tryParse(statusLine.substring(0, 3));
    final message = statusLine.substring(3).replaceFirst(' ', '');

    final responseHeadersBuilder = HeadersBuilder();
    final responseHeaderLineCount = int.tryParse(lines[cursor++]);

    for (var i = 0; i < responseHeaderLineCount; i++) {
      responseHeadersBuilder.addLine(lines[cursor++]);
    }

    var responseHeaders = responseHeadersBuilder.build();

    final sendRequestMillisString = responseHeaders.value(_sentMillis);
    final receivedResponseMillisString = responseHeaders.value(_receivedMillis);

    responseHeaders = responseHeaders
        .toBuilder()
        .remove(_sentMillis)
        .remove(_receivedMillis)
        .build();

    final sentRequestMillis = int.tryParse(sendRequestMillisString);
    final receivedResponseMillis = int.tryParse(receivedResponseMillisString);

    return Entry(
      url,
      requestMethod,
      varyHeaders,
      code,
      message,
      responseHeaders,
      sentRequestMillis,
      receivedResponseMillis,
    );
  }

  factory Entry.fromResponse(Response response) {
    final url = response.originalRequest.uriWithQueries.toString();
    final varyHeaders = _varyHeaders(response.originalRequest, response);
    final requestMethod = response.originalRequest.method;
    final code = response.code;
    final message = response.message;
    final responseHeaders = response.headers;
    final sentRequestMillis = response.sentAt.millisecondsSinceEpoch;
    final receivedResponseMillis = response.receivedAt.millisecondsSinceEpoch;

    return Entry(
      url,
      requestMethod,
      varyHeaders,
      code,
      message,
      responseHeaders,
      sentRequestMillis,
      receivedResponseMillis,
    );
  }

  static Headers _varyHeaders(
    Request request,
    Response response,
  ) {
    final fields = response.headers.vary();

    if (fields.isEmpty) {
      return HeadersBuilder().build();
    }

    final result = HeadersBuilder();

    for (var i = 0; i < request.headers.length; i++) {
      final name = request.headers.nameAt(i);

      if (fields.contains(name)) {
        result.add(name, request.headers.valueAt(i));
      }
    }

    return result.build();
  }
}
