import 'package:meta/meta.dart';

/// Define an API.
@immutable
class Api {
  final String baseUri;

  const Api([this.baseUri]);
}

@immutable
class Method {
  /// HTTP request method.
  final String name;

  /// The URL of the endpoint.
  final String path;

  const Method(this.name, this.path);
}

/// Make a `GET` request.
@immutable
class Get extends Method {
  const Get(String path) : super('GET', path);
}

/// Make a `POST` request.
@immutable
class Post extends Method {
  const Post(String path) : super('POST', path);
}

/// Make a `DELETE` request.
@immutable
class Delete extends Method {
  const Delete(String path) : super('DELETE', path);
}

/// Make a `PUT` request.
@immutable
class Put extends Method {
  const Put(String path) : super('PUT', path);
}

/// Make a `PATCH` request.
@immutable
class Patch extends Method {
  const Patch(String path) : super('PATCH', path);
}

/// Make a `HEAD` request.
@immutable
class Head extends Method {
  const Head(String path) : super('HEAD', path);
}

/// Make an `OPTIONS` request.
@immutable
class Options extends Method {
  const Options(String path) : super('OPTIONS', path);
}

/// Named replacement in a URL path segment.
@immutable
class Path {
  final String name;

  const Path([this.name]);
}

@immutable
abstract class Param {
  const Param();

  String get name;
}

/// Query parameter appended to the URL.
@immutable
class Query extends Param {
  @override
  final String name;

  const Query([this.name]);
}

/// Query parameter keys and values appended to the URL.
@immutable
class Queries {
  const Queries();
}

/// Header parameter appended to the URL.
@immutable
class Header extends Param {
  @override
  final String name;

  const Header([this.name]);
}

/// Header parameter keys and values appended to the URL.
@immutable
class Headers {
  const Headers();
}

/// Denotes that the parameter is a request body.
@immutable
class Body {
  final String contentType;

  const Body(this.contentType);
}

/// Denotes that the request body will use form URL encoding.
/// Also can denote that the parameter is the request's form.
@immutable
class Form extends Body {
  const Form() : super('application/x-www-form-urlencoded');
}

@immutable
class Field extends Param {
  @override
  final String name;

  const Field([this.name]);
}

/// Denotes that the request body is multi-part.
/// Also can denote that the parameter is the request's multi-part.
@immutable
class MultiPart extends Body {
  const MultiPart([String contentType = 'multipart/form-data'])
      : super(contentType);
}

/// Denotes a single part of a multi-part request.
@immutable
class Part {
  final String name;
  final String fileName;
  final String contentType;

  const Part({
    this.name,
    this.fileName = '',
    this.contentType,
  });
}

@immutable
class Extra {
  const Extra();
}
