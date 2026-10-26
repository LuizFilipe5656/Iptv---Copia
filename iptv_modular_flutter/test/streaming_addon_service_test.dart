import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_modular_flutter/models/addon.dart';
import 'package:iptv_modular_flutter/repositories/addon_repository.dart';
import 'package:iptv_modular_flutter/services/streaming_addon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('validates manifest URLs before importing', () {
    final service = DefaultStreamingAddonService();

    expect(service.isValidManifestUrl('https://addon.example/manifest.json'), isTrue);
    expect(service.isValidManifestUrl('ftp://addon.example/manifest.json'), isFalse);
    expect(service.isValidManifestUrl('not a url'), isFalse);

    service.close();
  });

  test('imports a valid addon manifest and stores it in the catalog', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.toString(), 'https://addon.example/manifest.json');
      return http.Response(
        jsonEncode({
          'id': 'custom-provider',
          'name': 'Custom Provider',
          'version': '1.2.3',
          'description': 'Provider de teste',
          'resources': ['stream'],
          'types': ['movie'],
          'catalogs': [
            {'id': 'popular', 'type': 'movie', 'name': 'Popular'},
          ],
        }),
        200,
      );
    });
    final repository = AddonRepository(client: mockClient);
    final service = DefaultStreamingAddonService(
      repository: repository,
      client: mockClient,
    );

    final addon = await service.addFromUrl(
      'https://addon.example/manifest.json',
      name: 'Meus Streams',
    );

    expect(addon.id, 'custom-provider');
    expect(addon.name, 'Meus Streams');
    expect(addon.enabled, isTrue);
    expect((await service.loadCatalog()).any((entry) => entry.id == 'custom-provider'), isTrue);

    service.close();
    repository.close();
  });

  test('rejects importing an already installed addon', () async {
    final repository = AddonRepository();
    final service = DefaultStreamingAddonService(
      repository: repository,
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'id': 'duplicate-provider',
              'name': 'Duplicate Provider',
              'resources': ['stream'],
              'types': ['movie'],
            }),
            200,
          )),
    );

    final custom = Addon(
      id: 'duplicate-provider',
      name: 'Duplicate Provider',
      url: 'https://duplicate.example/manifest.json',
      enabled: true,
    );
    await repository.saveAllAddons([custom]);

    await expectLater(
      service.addFromUrl('https://duplicate.example/manifest.json'),
      throwsA(isA<ArgumentError>()),
    );

    service.close();
    repository.close();
  });

  test('enables and removes a custom addon from the catalog', () async {
    final mockClient = MockClient((request) async {
      if (request.url.host == 'provider.example') {
        return http.Response(
          jsonEncode({
            'id': 'provider',
            'name': 'Provider',
            'version': '1.0.0',
            'description': 'Nova descricao',
            'resources': ['stream'],
            'types': ['movie'],
          }),
          200,
        );
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final repository = AddonRepository(client: mockClient);
    final service = DefaultStreamingAddonService(
      repository: repository,
      client: mockClient,
    );

    await service.addFromUrl('https://provider.example/manifest.json');

    await service.setEnabled('provider', false);
    expect(
      (await service.loadCatalog()).singleWhere((addon) => addon.id == 'provider').enabled,
      isFalse,
    );

    await service.remove('provider');
    expect(
      (await service.loadCatalog()).any((addon) => addon.id == 'provider'),
      isFalse,
    );

    service.close();
    repository.close();
  });
}
