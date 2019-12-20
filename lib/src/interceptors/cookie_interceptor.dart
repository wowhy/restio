import 'dart:io';

import 'package:restio/src/chain.dart';
import 'package:restio/src/cookie_jar.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/response.dart';

class CookieInterceptor implements Interceptor {
  final CookieJar cookieJar;

  CookieInterceptor({
    this.cookieJar,
  });

  @override
  Future<Response> intercept(Chain chain) async {
    var request = chain.request;

    if (cookieJar != null) {
      final cookies = await cookieJar.loadForRequest(request);

      final cookieHeader = _cookieHeader(cookies);

      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        request = request.copyWith(
          headers: request.headers
              .builder()
              .set(HttpHeaders.cookieHeader, cookieHeader)
              .build(),
        );
      }
    }

    var response = await chain.proceed(request);

    if (response != null) {
      final cookies = _obtainCookiesFromResponse(response);

      response = response.copyWith(
        cookies: cookies,
      );

      await cookieJar?.saveFromResponse(response, cookies);
    }

    return response;
  }

  String _cookieHeader(List<Cookie> cookies) {
    return cookies.map((item) => '${item.name}=${item.value}').join('; ');
  }

  List<Cookie> _obtainCookiesFromResponse(Response response) {
    final cookies = <Cookie>[];

    response.headers.forEach((name, value) {
      if (name == 'set-cookie') {
        try {
          final cookie = Cookie.fromSetCookieValue(value);
          if (cookie.name != null && cookie.name.isNotEmpty) {
            final domain = cookie.domain == null
                ? response.request.uri.host
                : cookie.domain.startsWith('.')
                    ? cookie.domain.substring(1)
                    : cookie.domain;
            final newCookie = Cookie(cookie.name, cookie.value)
              ..expires = cookie.expires
              ..maxAge = cookie.maxAge
              ..domain = domain
              ..path = cookie.path ?? response.request.uri.path
              ..secure = cookie.secure
              ..httpOnly = cookie.httpOnly;
            // Adiciona à lista de cookies a salvar.
            cookies.add(newCookie);
          }
        } catch (e) {
          // nada.
        }
      }
    });

    return cookies;
  }
}