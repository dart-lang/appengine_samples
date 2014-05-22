// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:appengine/appengine.dart';
import 'package:memcache/memcache.dart';

import 'package:route/server.dart';
import 'package:mustache/mustache.dart' as mustache;

final MAIN_PAGE = mustache.parse("""
<html>
  <head>
    <title>Main page</title>
    <style>
      div {
        padding: 10%;
      }
    </style>
</head>
  </head>
  <body>
    <div>
      <h2>Add new user:</h2>
      <form name="input" action="/mustache/" method="get">
        <input type="text" name="user">
        <input type="submit" value="Submit">
      </form>
  
      <h2>Existing Users:</h2>
      <ul>
        {{#users}}
          <li>{{user}}</li>
        {{/users}}
      </ul>
    </div>
  </body>
</html>
""");

sendResponse(HttpResponse response, int statusCode, String message,
             {bool isHtml: false}) {
  var data = UTF8.encode(message);
  response.headers.contentType =
      new ContentType('text', isHtml ? 'html' : 'plain', charset: 'utf-8');
  response.headers.set("Cache-Control", "no-cache");
  response.statusCode = statusCode;
  response.contentLength = data.length;
  response.add(data);
  response.close();
}

serveMustache(HttpRequest request) {
  Memcache memcache = contextFromRequest(request).services.memcache;

  request.drain().then((_) {
    var newUser = request.uri.queryParameters['user'];

    Map users = {'users' : []};
    memcache.get('users').then((String encodedUsers) {
      users = JSON.decode(encodedUsers);
    }).catchError((_){}).whenComplete(() {
      if (newUser != null) users['users'].add({'user': newUser});

      memcache.set('users', JSON.encode(users)).then((_) {
        var buffer = new StringBuffer();
        MAIN_PAGE.render(users, buffer);
        sendResponse(request.response, HttpStatus.OK, "$buffer", isHtml: true);
      });
    });
  });
}

main() {
  runAppEngine().then((Stream<HttpRequest> requestStream) {
    var router = new Router(requestStream)
        ..defaultStream.listen(serveMustache);
  });
}
