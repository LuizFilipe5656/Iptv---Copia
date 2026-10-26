# Sistema de Metadados Multi-Addon

Este documento descreve o novo sistema de busca de metadados que agrega informações de TODOS os addons instalados, não apenas do Cinemeta.

## 📋 Visão Geral

O sistema foi refatorado para:

1. **Buscar metadados de todos os addons em paralelo** usando `Promise.allSettled`
2. **Fazer merge inteligente** de temporadas e episódios, removendo duplicatas
3. **Sincronizar catálogos com Supabase** com rastreamento de origem (addon)
4. **Manter Cinemeta como fallback**, mas nunca como fonte única

## 🆕 Novos Arquivos

### 1. MultiAddonMetadataService
`lib/services/multi_addon_metadata_service.dart`

Serviço principal que agrega metadados de múltiplos addons:

- `fetchSeriesMetadata()` - Busca episódios de TODOS os addons em paralelo
- `fetchMovieMetadata()` - Busca metadados de filme de TODOS os addons
- Usa `Future.waitSettled` para não quebrar se um addon estiver offline
- Faz merge inteligente de episódios (mantém o mais completo)

### 2. SupabaseCatalogService
`lib/services/supabase_catalog_service.dart`

Serviço para sincronizar catálogos com o Supabase:

- `syncCatalogsFromAllAddons()` - Sincroniza todos os catálogos de todos os addons
- `syncAddonCatalogs()` - Sincroniza catálogos de um addon específico
- Salva de qual addon veio cada informação (`addon_sources`)
- Busca filmes/séries do Supabase

### 3. CatalogSyncHelper
`lib/services/catalog_sync_helper.dart`

Helper para facilitar a sincronização:

- `syncCatalogsFromAllAddons()` - Função estática principal
- `syncAddonCatalogs()` - Sincroniza addon específico
- `quickSync()` - Sincronização rápida (incremental)
- `fullSync()` - Sincronização completa (inicial)
- `needsSync()` - Verifica se sincronização é necessária

### 4. SQL de Catálogos
`supabase_catalog_tables.sql`

Script SQL para criar tabelas de catálogo no Supabase:

- Tabela `movies` - Armazena filmes
- Tabela `series` - Armazena séries
- Índices para performance (full-text search, gêneros, addon sources)
- Views úteis (popular_movies, popular_series, recent_content)
- Funções auxiliares (search, por gênero, por addon)

## 🔧 Modificações

### SeriesMetadataService
Atualizado para usar o novo aggregator:

```dart
// Antes: usava apenas Cinemeta + alguns addons sequencialmente
// Agora: usa MultiAddonMetadataService por padrão

final service = SeriesMetadataService(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
  useMultiAddonAggregator: true, // NOVO: ativa aggregator
);
```

Para desativar o aggregator e usar o comportamento legado:

```dart
final service = SeriesMetadataService(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
  useMultiAddonAggregator: false, // usa comportamento legado
);
```

### Movie Model
Adicionado campo `updatedAt` para rastreamento:

```dart
class Movie {
  // ... campos existentes
  final String? updatedAt; // NOVO
}
```

## 🚀 Como Usar

### 1. Configurar Supabase

Execute o SQL no painel do Supabase:

```bash
# Copie o conteúdo de supabase_catalog_tables.sql
# Cole no SQL Editor do Supabase
# Execute
```

### 2. Usar MultiAddonMetadataService

```dart
import '../services/multi_addon_metadata_service.dart';

final service = MultiAddonMetadataService(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
);

// Buscar metadados de série de TODOS os addons
final metadata = await service.fetchSeriesMetadata(
  series: movie,
  type: 'series',
);

// Buscar metadados de filme de TODOS os addons
final enrichedMovie = await service.fetchMovieMetadata(
  movie: movie,
  type: 'movie',
);
```

### 3. Sincronizar Catálogos com Supabase

```dart
import '../services/catalog_sync_helper.dart';

// Sincronização completa de todos os addons
final result = await CatalogSyncHelper.syncCatalogsFromAllAddons(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
  batchSize: 50,
  onProgress: () {
    // Atualizar UI de progresso
  },
);

print('Processados: ${result.totalProcessed}');
print('Adicionados: ${result.totalAdded}');
print('Atualizados: ${result.totalUpdated}');
```

### 4. Sincronização Rápida

```dart
// Quick sync para atualizações incrementais
final result = await CatalogSyncHelper.quickSync(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
  itemsPerCatalog: 20,
);
```

### 5. Verificar se Precisa Sincronizar

```dart
final needsSync = await CatalogSyncHelper.needsSync(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
  threshold: Duration(hours: 24),
);

if (needsSync) {
  await CatalogSyncHelper.syncCatalogsFromAllAddons(
    addonRepository: addonRepository,
    catalogRepository: catalogRepository,
  );
}
```

## 📊 Estrutura das Tabelas Supabase

### movies
```sql
CREATE TABLE movies (
    id UUID PRIMARY KEY,
    content_id TEXT UNIQUE,          -- ID único do conteúdo
    imdb_id TEXT,                     -- IMDb ID
    title TEXT,                       -- Título
    type TEXT,                        -- 'movie'
    overview TEXT,                    -- Sinopse
    poster_url TEXT,                  -- URL do poster
    banner_url TEXT,                  -- URL do banner
    imdb_rating NUMERIC,              -- Nota IMDb
    release_year INTEGER,             -- Ano de lançamento
    genres TEXT[],                    -- Lista de gêneros
    addon_sources TEXT[],             -- IDs dos addons que têm este conteúdo
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

### series
```sql
CREATE TABLE series (
    id UUID PRIMARY KEY,
    content_id TEXT UNIQUE,          -- ID único do conteúdo
    imdb_id TEXT,                     -- IMDb ID
    title TEXT,                       -- Título
    type TEXT,                        -- 'series', 'anime', etc
    overview TEXT,                    -- Sinopse
    poster_url TEXT,                  -- URL do poster
    banner_url TEXT,                  -- URL do banner
    imdb_rating NUMERIC,              -- Nota IMDb
    release_year INTEGER,             -- Ano de lançamento
    genres TEXT[],                    -- Lista de gêneros
    addon_sources TEXT[],             -- IDs dos addons que têm este conteúdo
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

## 🔍 Como Funciona o Merge

### Merge de Episódios

1. Cada addon retorna uma lista de episódios
2. Episodes são agrupados por `season:episode` (chave única)
3. Se houver duplicata, mantém o episódio com mais informações:
   - Sinopse mais completa
   - Thumbnail disponível
   - Runtime disponível
   - Kind/type disponível

### Merge de Metadados de Filme

1. Cada addon retorna metadados do filme
2. Merge prioritário:
   - Sinopse em português primeiro, depois outras
   - Poster de qualquer addon
   - Banner de qualquer addon
   - IMDb rating mais alto
   - Gêneros mais completos

## 🎯 Addons Suportados

O sistema busca metadados de TODOS os addons instalados:

- Cinemeta (como fallback, não mais como única fonte)
- YouTube
- Public Domain Movies
- Open Subtitles V3
- FrostStream
- FenixFlix
- Comet | ElfHosted
- Streaming Catalogs
- The Movie Database Addon
- Marvel
- Metadados AIO
- Catálogos de Streaming Plus
- StreamAsia
- + Addons customizados instalados

## ⚡ Performance

### Paralelismo

- Usa `Future.waitSettled` para buscar de todos os addons simultaneamente
- Não quebra se um addon estiver offline
- Logs de debug mostram quais addons falharam

### Batching

- Sincronização com Supabase usa batches configuráveis (padrão: 50)
- Reduz número de requisições
- Melhora performance

### Caching

- Manifest dos addons é cacheado localmente
- Catálogos são cacheados no Supabase
- Reduz chamadas repetitivas

## 🐛 Troubleshooting

### Episódios não aparecendo

Verifique os logs:
```
[multi-addon] Fetching series metadata for: Título
[multi-addon] Total addons to query: X
[multi-addon] addon-name: Found N episodes via meta
[multi-addon] addon-name: Found N episodes via catalog
[multi-addon] Final result:
[multi-addon] - Seasons: X
[multi-addon] - Episodes: Y
[multi-addon] - Sources: N/X
```

### Sincronização falhando

Verifique:
1. Se as tabelas do Supabase foram criadas (`supabase_catalog_tables.sql`)
2. Se o usuário tem permissão de admin (RLS)
3. Se os addons estão instalados e habilitados

### Cinemeta ainda sendo usado

O Cinemeta agora é apenas um dos muitos addons. Se você quer usar apenas ele:
```dart
final service = SeriesMetadataService(
  useMultiAddonAggregator: false,
);
```

## 📝 Exemplo Completo

```dart
// Inicializar serviços
final addonRepository = AddonRepository();
final catalogRepository = CatalogRepository();

// Sincronizar catálogos (pode ser feito uma vez por dia)
final syncResult = await CatalogSyncHelper.syncCatalogsFromAllAddons(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
);

print('Sincronização completa: ${syncResult.totalProcessed} itens');

// Buscar metadados usando o novo aggregator
final multiAddonService = MultiAddonMetadataService(
  addonRepository: addonRepository,
  catalogRepository: catalogRepository,
);

final metadata = await multiAddonService.fetchSeriesMetadata(
  series: movie,
  type: 'series',
);

print('Encontrados ${metadata.seasons.length} temporadas');
print('Encontrados ${metadata.episodes.length} episódios');
```

## 🔄 Migração do Sistema Antigo

O sistema é compatível com o código existente:

1. `SeriesMetadataService` continua funcionando (usa aggregator por padrão)
2. Adicionei flag `useMultiAddonAggregator` para desativar se necessário
3. Model `Movie` backward compatible (campo `updatedAt` é opcional)

Para migrar completamente:

1. Execute o SQL `supabase_catalog_tables.sql`
2. Rode uma sincronização inicial: `CatalogSyncHelper.fullSync()`
3. Configure sincronização periódica (ex: diária)
4. Monitore os logs para ver quais addons estão funcionando

## 🎓 Boas Práticas

1. **Sincronização Inicial**: Use `fullSync()` na primeira vez
2. **Atualizações**: Use `quickSync()` para atualizações diárias
3. **Progresso**: Use `onProgress` callback para mostrar progresso na UI
4. **Batch Size**: Ajuste conforme sua infraestrutura (50-100 é bom)
5. **Erro Handling**: Sempre use `try-catch` e mostre mensagens amigáveis
6. **Logs**: Mantenha debugPrint ativo durante desenvolvimento

## 📞 Suporte

Para dúvidas ou problemas, consulte:
- Documentação Supabase: https://supabase.com/docs
- Código fonte em `lib/services/multi_addon_metadata_service.dart`
- Código fonte em `lib/services/supabase_catalog_service.dart`
