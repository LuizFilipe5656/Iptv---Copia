$ErrorActionPreference = 'Stop'
$arquivo = Join-Path (Get-Location) 'lib\screens\episode_screen.dart'
if (-not (Test-Path $arquivo)) { throw "Arquivo nao encontrado: $arquivo. Execute na raiz do projeto Flutter." }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$texto = [System.IO.File]::ReadAllText($arquivo, [System.Text.Encoding]::UTF8)
$oldImport = "import 'package:flutter/material.dart';"
$newImport = "import 'dart:convert';`n`nimport 'package:flutter/material.dart';`nimport 'package:http/http.dart' as http;"
$oldId = 'final seriesId = series.imdbId ?? series.id;'
$newId = 'final seriesId = await _resolveStreamSeriesId();' 
$oldPlayback = 'playbackContentId: seriesId,'
$newPlayback = 'playbackContentId: series.id,'
$anchor = '  SeriesEpisode? _followingEpisode(SeriesEpisode target) {'
$helper = @'
  Future<String> _resolveStreamSeriesId() async {
    final originalId = series.id;
    final imdbId = series.imdbId;
    final imdbPattern = RegExp(r'^tt\d+$', caseSensitive: false);

    if (imdbId != null && imdbPattern.hasMatch(imdbId.trim())) {
      return imdbId.trim();
    }
    if (imdbPattern.hasMatch(originalId.trim())) {
      return originalId.trim();
    }

    final tvmazeMatch = RegExp(r'^tvmaze:(\d+)$').firstMatch(originalId);
    if (tvmazeMatch == null) {
      debugPrint('[cine] Sem IMDb confirmado para ${series.title}; usando $originalId');
      return originalId;
    }

    try {
      final uri = Uri.https(
        'api.tvmaze.com',
        '/shows/${tvmazeMatch.group(1)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final externals = decoded['externals'];
          if (externals is Map) {
            final candidate = externals['imdb']?.toString().trim();
            if (candidate != null && imdbPattern.hasMatch(candidate)) {
              debugPrint('[cine] TVMaze $originalId -> IMDb $candidate');
              return candidate;
            }
          }
        }
      }
      debugPrint('[cine] TVMaze sem IMDb confirmado para $originalId (HTTP ${response.statusCode})');
    } catch (error) {
      debugPrint('[cine] Falha ao consultar IMDb de $originalId: $error');
    }
    return originalId;
  }

'@
foreach ($entry in @(@($oldImport,$newImport), @($oldId,$newId), @($oldPlayback,$newPlayback), @($anchor,($helper+$anchor)))) {
  if (-not $texto.Contains($entry[0])) { throw "Trecho esperado nao encontrado: $($entry[0]). Nenhuma alteracao realizada." }
}
if ($texto.Contains('Future<String> _resolveStreamSeriesId()')) { throw 'Correcao ja aplicada. Nenhuma alteracao realizada.' }
$backup = "$arquivo.bak_ids_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item -LiteralPath $arquivo -Destination $backup
$texto = $texto.Replace($oldImport,$newImport).Replace($oldId,$newId).Replace($oldPlayback,$newPlayback).Replace($anchor,($helper+$anchor))
[System.IO.File]::WriteAllText($arquivo, $texto, $utf8)
Write-Host "Correcao aplicada. Backup: $backup" -ForegroundColor Green
Write-Host 'Execute: dart format lib\screens\episode_screen.dart; flutter analyze' -ForegroundColor Cyan
