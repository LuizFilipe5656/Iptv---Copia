$ErrorActionPreference = 'Stop'
$arquivo = 'lib\screens\addon_category_screen.dart'
if (-not (Test-Path $arquivo)) { throw "Arquivo nao encontrado: $arquivo. Execute na raiz do projeto Flutter." }
$codigo = [System.IO.File]::ReadAllText((Resolve-Path $arquivo).Path, [System.Text.Encoding]::UTF8)
if ($codigo.Contains('[cine-catalog]')) { throw 'Integracao ja parece instalada. Nenhuma alteracao feita.' }

# PowerShell: construcao literal, sem expansao de variaveis
$ancora = 'debugPrint(''ADDONS INSTALADOS: ${installed.length}'');'
if (($codigo.Split([string[]]@($ancora), [StringSplitOptions]::None).Length - 1) -ne 1) {
  throw 'Ancora ADDONS INSTALADOS nao encontrada exatamente uma vez. Nenhuma alteracao feita.'
}
$insercao = @'
        // Catalogos independentes: nao representam addons de reproducao.
        if (widget.category == AddonCategory.doramas) {
          try {
            final doramas = await doramaService.getPopularDoramas();
            if (!mounted || currentGeneration != generation) return;
            final source = Addon(
              id: 'catalog_tvmaze',
              name: 'TVMaze (catálogo)',
            );
            final batch = <_CatalogEntry>[];
            for (final item in doramas) {
              final key = '${item.type}|${item.id}';
              if (seen.add(key)) {
                batch.add(_CatalogEntry(addon: source, item: item));
              }
            }
            if (batch.isNotEmpty) setState(() => items.addAll(batch));
            debugPrint('[cine-catalog] TVMaze: ${batch.length} doramas');
          } catch (error) {
            failures++;
            debugPrint('[cine-catalog] Erro TVMaze: $error');
          }
        } else if (widget.category == AddonCategory.anime) {
          try {
            final animes = await animeService.getPopularAnimes();
            if (!mounted || currentGeneration != generation) return;
            final batch = <_CatalogEntry>[];
            for (final anime in animes) {
              final item = AnimeStremioAdapter.convert(anime);
              final key = '${item.type}|${item.id}';
              if (seen.add(key)) {
                batch.add(_CatalogEntry(
                  addon: Addon(
                    id: 'catalog_${anime.source.toLowerCase()}',
                    name: '${anime.source} (catálogo)',
                  ),
                  item: item,
                ));
              }
            }
            if (batch.isNotEmpty) setState(() => items.addAll(batch));
            debugPrint('[cine-catalog] Anime: ${batch.length} títulos');
          } catch (error) {
            failures++;
            debugPrint('[cine-catalog] Erro Anime: $error');
          }
        }
'@
$codigo = $codigo.Replace($ancora, $ancora + "`r`n" + $insercao)

$dispose = '    super.dispose();'
if (($codigo.Split([string[]]@($dispose), [StringSplitOptions]::None).Length - 1) -ne 1) {
  throw 'Ancora dispose nao encontrada exatamente uma vez. Nenhuma alteracao feita.'
}
$codigo = $codigo.Replace($dispose, "    doramaService.close();`r`n    animeService.close();`r`n" + $dispose)

$backup = "$arquivo.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item -LiteralPath $arquivo -Destination $backup -ErrorAction Stop
[System.IO.File]::WriteAllText((Resolve-Path $arquivo).Path, $codigo, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Integracao aplicada. Backup: $backup" -ForegroundColor Green
Write-Host 'Proximos passos: dart format lib\screens\addon_category_screen.dart; flutter analyze' -ForegroundColor Cyan
