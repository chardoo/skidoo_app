import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/features/discovery/data/datasources/discovery_remote_data_source.dart';

/// GET /photographer/events/{id}/images pages the pictures at the top level
/// and puts the event beside them:
///
///   { "data": [ …pictures… ], "pagination": {…}, "event": { …event… } }
///
/// EventDiscovery looks for pictures *inside* the event, so without folding
/// them in every event fetched by id arrived with an empty album — and
/// anything that opened one opened nothing at all, silently.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _response({required List<Map<String, dynamic>> pictures}) => {
      'data': pictures,
      'pagination': {'page': 1, 'limit': 25, 'total': pictures.length},
      'event': {
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'url': 'https://cdn.example.com/cover.jpg',
        'user': {'id': 'ph-1', 'name': 'Daniella Daniels'},
      },
    };

Map<String, dynamic> _picture(String id) => {
      'id': id,
      'imageId': 'img-$id',
      'url': 'https://cdn.example.com/$id.jpg',
      'price': 25,
      'public': true,
      'mediaType': 'image',
      'width': 4000,
      'height': 6000,
    };

void main() {
  late DiscoveryRemoteDataSourceImpl source;

  setUp(() => source = DiscoveryRemoteDataSourceImpl(Api()));

  test('an event fetched by id carries its pictures', () async {
    Api().dio.httpClientAdapter = _StubAdapter(
      _response(pictures: [_picture('pic-1'), _picture('pic-2')]),
    );

    final event = await source.getEventById('evt-1');

    expect(event.eventName, 'Praise Reloaded 2026');
    // The whole point: an empty list here is a tap that goes nowhere.
    expect(event.pictures, hasLength(2));
    expect(event.pictures.first.url, 'https://cdn.example.com/pic-1.jpg');
    expect(event.photographerName, 'Daniella Daniels');
  });

  test('an event with no pictures is still an event', () async {
    Api().dio.httpClientAdapter = _StubAdapter(_response(pictures: []));

    final event = await source.getEventById('evt-1');

    expect(event.id, 'evt-1');
    expect(event.pictures, isEmpty);
  });
}
