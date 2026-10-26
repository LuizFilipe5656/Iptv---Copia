import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_modular_flutter/models/addon.dart';
import 'package:iptv_modular_flutter/models/stremio_addon_manifest.dart';
import 'package:iptv_modular_flutter/repositories/addon_repository.dart';
import 'package:iptv_modular_flutter/services/addon_configuration_service.dart';
import 'package:iptv_modular_flutter/services/addon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads official bundled addons as fixed and enabled', () async {
    final service = AddonService();
    final addons = await service.loadCatalog();

    expect(addons, hasLength(8));
    expect(addons.every((addon) => addon.fixed && addon.enabled), isTrue);
    expect(
      addons.map((addon) => addon.id),
      [
        'cinemeta',
        'youtube',
        'public_domain_movies',
        'opensubtitles_v3',
        'froststream',
        'fenixflix',
        'comet.elfhosted.com',
        'pw.ers.netflix-catalog',
      ],
    );
    service.close();
  });

  test('does not allow changing or removing fixed addons', () async {
    final service = AddonService();
    await service.loadCatalog();

    await expectLater(
      service.setInstalled('cinemeta', false),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.removeAddon('cinemeta'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => service.unregister('cinemeta'),
      throwsA(isA<StateError>()),
    );
    service.close();
  });

  test('removes previously installed addon and its saved data on startup',
      () async {
    SharedPreferences.setMockInitialValues({
      AddonRepository.customAddonsKey: jsonEncode([
        {
          'id': 'torrentio',
          'name': 'Torrentio',
          'url': 'https://legacy.example/manifest.json',
          'enabled': true,
          'fixed': false,
        },
        {
          'id': 'custom-addon',
          'name': 'Custom Addon',
          'url': 'https://custom.example/manifest.json',
          'enabled': true,
          'fixed': false,
        },
      ]),
      AddonRepository.installedAddonsKey:
          jsonEncode({'torrentio': true, 'custom-addon': true}),
      AddonRepository.addonConfigurationKey: jsonEncode({
        'torrentio': {'quality': '1080p'},
        'froststream': {'language': 'pt'},
      }),
      AddonRepository.configuredAddonUrlsKey: jsonEncode({
        'torrentio': {
          'originalAddonId': 'torrentio',
          'configuredAddonId': 'com.torrentio',
          'configuredManifestUrl': 'https://legacy.example/manifest.json',
        },
      }),
      'stremio_catalog_abcd': '{"items":[]}',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = AddonRepository(preferences: preferences);

    final addons = await repository.getAllAddons();

    expect(addons.map((addon) => addon.id), isNot(contains('torrentio')));
    expect(addons.map((addon) => addon.id), contains('custom-addon'));
    expect(
      jsonDecode(preferences.getString(AddonRepository.customAddonsKey)!),
      hasLength(1),
    );
    expect(
      jsonDecode(preferences.getString(AddonRepository.installedAddonsKey)!),
      {'custom-addon': true},
    );
    expect(
      jsonDecode(
        preferences.getString(AddonRepository.addonConfigurationKey)!,
      ),
      {
        'froststream': {'language': 'pt'}
      },
    );
    expect(
      jsonDecode(
        preferences.getString(AddonRepository.configuredAddonUrlsKey)!,
      ),
      isEmpty,
    );
    expect(preferences.getString('stremio_catalog_abcd'), isNull);
    repository.close();
  });

  test('removes the legacy TV addon and its saved data on startup', () async {
    SharedPreferences.setMockInitialValues({
      AddonRepository.customAddonsKey: jsonEncode([
        {
          'id': 'community.stremio-iptv',
          'name': 'Stremio IPTV',
          'url': 'https://ryann-devv.github.io/Stremio-IPTV/manifest.json',
          'enabled': true,
          'fixed': false,
        },
        {
          'id': 'custom-addon',
          'name': 'Custom Addon',
          'url': 'https://custom.example/manifest.json',
          'enabled': true,
          'fixed': false,
        },
      ]),
      AddonRepository.installedAddonsKey: jsonEncode({
        'community.stremio-iptv': true,
        'custom-addon': true,
      }),
      AddonRepository.addonConfigurationKey: jsonEncode({
        'community.stremio-iptv': {'country': 'br'},
        'custom-addon': {'language': 'pt'},
      }),
      AddonRepository.configuredAddonUrlsKey: jsonEncode({
        'community.stremio-iptv': {
          'originalAddonId': 'community.stremio-iptv',
          'configuredAddonId': 'community.stremio-iptv',
          'configuredManifestUrl':
              'https://ryann-devv.github.io/Stremio-IPTV/manifest.json',
        },
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = AddonRepository(preferences: preferences);

    final addons = await repository.getAllAddons();

    expect(addons.map((addon) => addon.id),
        isNot(contains('community.stremio-iptv')));
    expect(addons.map((addon) => addon.id), contains('custom-addon'));
    expect(
      jsonDecode(preferences.getString(AddonRepository.customAddonsKey)!),
      hasLength(1),
    );
    expect(
      jsonDecode(preferences.getString(AddonRepository.installedAddonsKey)!),
      {'custom-addon': true},
    );
    expect(
      jsonDecode(preferences.getString(AddonRepository.addonConfigurationKey)!),
      {
        'custom-addon': {'language': 'pt'}
      },
    );
    expect(
      jsonDecode(
        preferences.getString(AddonRepository.configuredAddonUrlsKey)!,
      ),
      isEmpty,
    );
    repository.close();
  });

  test('reports invalid manifests and connection failures', () async {
    final invalidManifestService = AddonService(
      client: MockClient((_) async => http.Response('not-json', 200)),
    );
    await expectLater(
      invalidManifestService.importFromUrl(
        'https://addons.example/manifest.json',
        name: 'Fonte de teste',
      ),
      throwsFormatException,
    );
    invalidManifestService.close();

    final offlineService = AddonService(
      client: MockClient((_) async {
        throw http.ClientException('Connection refused');
      }),
    );
    await expectLater(
      offlineService.importFromUrl('https://addons.example/manifest.json'),
      throwsA(isA<http.ClientException>()),
    );
    offlineService.close();
  });

  test('repository combines fixed and saved custom addons', () async {
    final repository = AddonRepository();
    final defaults = await repository.getAllAddons();
    final custom = Addon(
      id: 'my-addon',
      name: 'Minha fonte',
      url: 'https://addons.example/manifest.json',
    );
    await repository.saveAllAddons([...defaults, custom]);

    final combined = await repository.getAllAddons();

    expect(combined, hasLength(9));
    expect(combined.where((addon) => addon.fixed), hasLength(8));
    expect(
        combined.singleWhere((addon) => addon.id == 'my-addon').fixed, isFalse);
  });

  test('background metadata providers are hidden from addon management', () async {
    final repository = AddonRepository();
    final visible = await repository.getAllAddons();
    final metadataProviders = await repository.getContentMetadataProviders();

    expect(visible, hasLength(8));
    expect(visible.map((addon) => addon.id), isNot(contains('org.aistreams.v2')));
    expect(
      metadataProviders.map((addon) => addon.id),
      containsAll([
        'org.aistreams.v2',
        'org.fayallc.animee.1',
        'com.zorak.plotcard',
        'com.zorak.marquee',
      ]),
    );
    expect(
      metadataProviders
          .where((addon) => addon.id.startsWith('com.zorak.'))
          .every((addon) => !addon.fixed),
      isTrue,
    );
  });

  test('builds Stremio configuration in the manifest path', () {
    final repository = AddonRepository();
    final configurationService = AddonConfigurationService(repository);
    final manifest = StremioAddonManifest.fromJson({
      'id': 'configurable-addon',
      'name': 'Configurable Addon',
      'configuration': [
        {
          'key': 'providers',
          'type': 'multiselect',
          'options': ['provider-a', 'provider-b'],
        },
        {
          'key': 'quality',
          'type': 'select',
          'options': ['4k', '1080p'],
        },
      ],
    });

    final configuredUrl = configurationService.buildManifestUrl(
      currentManifestUrl:
          'https://configurable.example/old=value%7Cquality=4k/manifest.json',
      manifest: manifest,
      values: {
        'providers': 'provider-a,provider-b',
        'quality': '1080p',
      },
    );

    expect(Uri.parse(configuredUrl).pathSegments, [
      'providers=provider-a,provider-b|quality=1080p',
      'manifest.json',
    ]);
    repository.close();
  });

  test('supports configurable manifests that expose no field schema', () {
    final repository = AddonRepository();
    final configurationService = AddonConfigurationService(repository);
    final addon = Addon(
      id: 'configurable-addon',
      name: 'Configurable Addon',
      url:
          'https://configurable.example/providers=provider-a|quality=1080p/manifest.json',
    );
    final manifest = StremioAddonManifest.fromJson({
      'id': 'configurable-addon',
      'name': 'Configurable Addon',
      'behaviorHints': {'configurable': true},
    });
    final values = configurationService.initialValues(
      addon: addon,
      manifest: manifest,
      savedValues: const {},
    );

    expect(values, {'providers': 'provider-a', 'quality': '1080p'});
    expect(
      Uri.parse(
        configurationService.buildManifestUrl(
          currentManifestUrl: addon.manifestUrl,
          manifest: manifest,
          values: {...values, 'language': 'pt'},
        ),
      ).pathSegments,
      [
        'providers=provider-a|quality=1080p|language=pt',
        'manifest.json',
      ],
    );
    repository.close();
  });

  test('installs and persists the configured manifest URL', () async {
    final manifestJson = {
      'id': 'com.froststream.configured',
      'name': 'FrostStream Configurado',
      'version': '1.2.3',
      'resources': ['stream'],
      'types': ['movie'],
      'behaviorHints': {'configurable': true},
      'configuration': [
        {
          'key': 'quality',
          'title': 'Qualidade',
          'type': 'select',
          'options': ['4k', '1080p'],
          'required': true,
        },
      ],
    };
    Uri? requestedUri;
    final repository = AddonRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode(manifestJson), 200);
      }),
    );
    final addons = await repository.getAllAddons();
    final froststream =
        addons.singleWhere((addon) => addon.id == 'froststream');
    final manifest = StremioAddonManifest.fromJson(manifestJson);
    final configurationService = AddonConfigurationService(repository);

    final configuredUrl = await configurationService.install(
      addon: froststream,
      manifest: manifest,
      values: const {'quality': '1080p'},
    );

    expect(requestedUri!.pathSegments, ['quality=1080p', 'manifest.json']);
    expect(
      (await repository.getAllAddons())
          .singleWhere((addon) => addon.id == 'froststream')
          .manifestUrl,
      configuredUrl,
    );
    final installedAddon = (await repository.getAllAddons())
        .singleWhere((addon) => addon.id == 'froststream');
    expect(installedAddon.originalAddonId, 'froststream');
    expect(installedAddon.configuredAddonId, 'com.froststream.configured');
    expect(installedAddon.installedAddonId, 'com.froststream.configured');
    expect(installedAddon.configuredManifestUrl, configuredUrl);
    expect(
      await repository.getManifest(installedAddon).then((value) => value.id),
      'com.froststream.configured',
    );
    expect(
      await repository.getAddonConfiguration('froststream'),
      {'quality': '1080p'},
    );
    repository.close();
  });

  test('rejects configured manifests without resources or valid versions',
      () async {
    for (final invalidManifest in [
      {
        'id': 'com.invalid.resources',
        'name': 'Invalid resources',
        'version': '1.0.0',
        'resources': [],
      },
      {
        'id': 'com.invalid.version',
        'name': 'Invalid version',
        'version': 'stable',
        'resources': ['stream'],
      },
    ]) {
      final repository = AddonRepository(
        client: MockClient(
          (_) async => http.Response(jsonEncode(invalidManifest), 200),
        ),
      );
      final froststream = (await repository.getAllAddons())
          .singleWhere((addon) => addon.id == 'froststream');
      await expectLater(
        repository.installConfiguredAddon(
          addon: froststream,
          manifestUrl: 'https://configured.example/manifest.json',
          configuration: const {},
        ),
        throwsFormatException,
      );
      repository.close();
    }
  });

  test('configures a user-added addon and marks it installed', () async {
    final manifestJson = {
      'id': 'com.custom.configured',
      'name': 'Custom Configurable',
      'version': '2.0.0',
      'resources': ['stream'],
      'types': ['movie'],
      'configuration': [
        {
          'key': 'token',
          'type': 'password',
          'required': true,
        },
      ],
    };
    final repository = AddonRepository(
      client:
          MockClient((_) async => http.Response(jsonEncode(manifestJson), 200)),
    );
    final addonService = AddonService(
      repository: repository,
      client: MockClient((request) async {
        final response = request.url.pathSegments.length > 1
            ? manifestJson
            : {...manifestJson, 'id': 'custom-configurable'};
        return http.Response(jsonEncode(response), 200);
      }),
    );
    final addon = await addonService.importFromUrl(
      'https://custom.example/manifest.json',
    );
    final manifest = StremioAddonManifest.fromJson(manifestJson);

    await AddonConfigurationService(repository).install(
      addon: addon,
      manifest: manifest,
      values: const {'token': 'private-value'},
    );

    final installed = (await repository.getAllAddons())
        .singleWhere((item) => item.id == addon.id);
    expect(installed.enabled, isTrue);
    expect(
      Uri.parse(installed.manifestUrl).pathSegments,
      ['token=private-value', 'manifest.json'],
    );
    expect(installed.originalAddonId, 'custom-configurable');
    expect(installed.configuredAddonId, 'com.custom.configured');
    expect(installed.installedAddonId, 'com.custom.configured');
    expect(installed.configuredManifestUrl, installed.manifestUrl);
    expect(
      await repository.getManifest(installed).then((value) => value.id),
      'com.custom.configured',
    );
    final updated = await addonService.update(addon.id);
    expect(updated.originalAddonId, 'custom-configurable');
    expect(updated.installedAddonId, 'com.custom.configured');
    expect(
      await repository.getAddonConfiguration(addon.id),
      {'token': 'private-value'},
    );
    addonService.close();
    repository.close();
  });
}
