import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:state_provider/state_provider.dart';

void main() {
  group('ApiClient', () {
    test('getJson returns AppSuccess on 200 with JSON body', () async {
      final capturedHeaders = <String, String?>{};
      final client = ApiClient(
        httpClient: MockClient((request) async {
          capturedHeaders['accept'] = request.headers['Accept'];
          return http.Response(jsonEncode({'value': 42}), 200);
        }),
      );

      final result = await client.getJson('https://example.com/value');

      expect(result.isSuccess, isTrue);
      expect(result.asSuccess.data.data, containsPair('value', 42));
      expect(result.asSuccess.data.statusCode, 200);
      expect(capturedHeaders['accept'], equals('application/json'));

      client.dispose();
    });

    test('getJson maps non-200 to AppFailure with appropriate error', () async {
      final client = ApiClient(
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Gone'}), 404);
        }),
      );

      final result = await client.getJson('https://example.com/missing');

      expect(result.isFailure, isTrue);
      final error = result.asFailure.error;
      expect(error.type, AppErrorType.notFound);
      expect(error.message, isNotEmpty);

      client.dispose();
    });

    test(
      'authHeadersBuilder injects custom headers when authenticated',
      () async {
        String? authorizationHeader;
        final client = ApiClient(
          httpClient: MockClient((request) async {
            authorizationHeader = request.headers['Authorization'];
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
          authHeadersBuilder: () async => const {
            'Authorization': 'Bearer token',
          },
        );

        await client.getJson('https://example.com/authenticated');

        expect(authorizationHeader, equals('Bearer token'));

        client.dispose();
      },
    );
  });
}
