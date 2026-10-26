import 'package:flutter/foundation.dart';

import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import 'supabase_catalog_service.dart';

/// Helper para facilitar a sincronização de catálogos
/// Pode ser chamado de qualquer lugar do app
class CatalogSyncHelper {
  CatalogSyncHelper({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
  })  : _addonRepository = addonRepository,
        _catalogRepository = catalogRepository;

  final AddonRepository _addonRepository;
  final CatalogRepository _catalogRepository;

  late final _catalogService = SupabaseCatalogService(
    addonRepository: _addonRepository,
    catalogRepository: _catalogRepository,
  );

  /// Sincroniza catálogos de TODOS os addons instalados
  /// Esta é a função principal solicitada
  static Future<CatalogSyncResult> syncCatalogsFromAllAddons({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
    int batchSize = 50,
    VoidCallback? onProgress,
  }) async {
    final helper = CatalogSyncHelper(
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
    );

    return await helper._catalogService.syncCatalogsFromAllAddons(
      batchSize: batchSize,
      onProgress: onProgress,
    );
  }

  /// Sincroniza catálogos de um addon específico
  static Future<CatalogSyncResult> syncAddonCatalogs({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
    required String addonId,
    int batchSize = 50,
  }) async {
    final helper = CatalogSyncHelper(
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
    );

    final addons = await addonRepository.getInstalledAddons();
    final addon = addons.firstWhere(
      (a) => a.id == addonId,
      orElse: () => throw ArgumentError('Addon $addonId not found'),
    );

    return await helper._catalogService.syncAddonCatalogs(
      addon,
      batchSize: batchSize,
    );
  }

  /// Sincronização rápida para atualizações incrementais
  /// Apenas busca dos últimos N itens de cada catálogo
  static Future<CatalogSyncResult> quickSync({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
    int itemsPerCatalog = 20,
  }) async {
    debugPrint('[catalog-sync] Starting quick sync (items per catalog: $itemsPerCatalog)');

    final helper = CatalogSyncHelper(
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
    );

    // Para quick sync, usa batch size menor
    return await helper._catalogService.syncCatalogsFromAllAddons(
      batchSize: 20,
    );
  }

  /// Sincronização completa para atualização inicial
  /// Busca TODOS os itens de TODOS os catálogos
  static Future<CatalogSyncResult> fullSync({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
    VoidCallback? onProgress,
  }) async {
    debugPrint('[catalog-sync] Starting full sync (all items from all catalogs)');

    final helper = CatalogSyncHelper(
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
    );

    return await helper._catalogService.syncCatalogsFromAllAddons(
      batchSize: 100,
      onProgress: onProgress,
    );
  }

  /// Verifica se uma sincronização é necessária
  /// Compara a data da última sincronização com a data atual
  static Future<bool> needsSync({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
    Duration threshold = const Duration(hours: 24),
  }) async {
    final helper = CatalogSyncHelper(
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
    );

    try {
      final mostRecentMovie = await helper._catalogService.fetchAllMovies();
      final mostRecentSeries = await helper._catalogService.fetchAllSeries();

      if (mostRecentMovie.isEmpty && mostRecentSeries.isEmpty) {
        return true; // Primeira sincronização
      }

      // Verifica a data mais recente
      final now = DateTime.now();
      final lastSync = mostRecentMovie.isNotEmpty
          ? DateTime.parse(mostRecentMovie.first.updatedAt ?? now.toIso8601String())
          : DateTime.parse(mostRecentSeries.first.updatedAt ?? now.toIso8601String());

      return now.difference(lastSync) > threshold;
    } catch (error) {
      debugPrint('[catalog-sync] Error checking sync status: $error');
      return true; // Em caso de erro, assume que precisa sincronizar
    }
  }
}
