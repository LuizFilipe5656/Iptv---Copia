$ErrorActionPreference = 'Stop'
$arquivo = 'lib\screens\addon_category_screen.dart'
if (-not (Test-Path $arquivo)) { throw "Arquivo nao encontrado: $arquivo. Execute na raiz do projeto Flutter." }
$codigo = [System.IO.File]::ReadAllText((Resolve-Path $arquivo).Path)
$import = "import '../services/external_episode_service.dart';"
$marcadorImport = "import '../services/dorama_catalog_service.dart';"
$marcadorMetodo = '    if (!mounted) return;'
$marcadorInsercao = @'
    // Titulos externos nao possuem manifesto de addon Stremio.
    // Carrega episodios usando o identificador original (tvmaze:/mal:).
    if (item.id.startsWith('tvmaze:') || item.id.startsWith('mal:')) {
      item = await ExternalEpisodeService.enrich(item);
    }

'@
if ($codigo.Contains('item = await ExternalEpisodeService.enrich(item);')) {
  Write-Host 'Integracao de episodios ja aplicada. Nenhuma alteracao.' -ForegroundColor Yellow
  exit 0
}
if (-not $codigo.Contains($marcadorImport)) { throw 'Importacao de referencia nao encontrada. Nenhum arquivo alterado.' }
$inicio = $codigo.IndexOf('  Future<void> openDetails(_CatalogEntry entry) async {')
$fim = $codigo.IndexOf('  Future<bool> _hasStream(', $inicio)
if ($inicio -lt 0 -or $fim -lt 0) { throw 'Metodo openDetails nao encontrado. Nenhum arquivo alterado.' }
$trecho = $codigo.Substring($inicio, $fim - $inicio)
if (-not $trecho.Contains($marcadorMetodo)) { throw 'Ponto de insercao nao encontrado. Nenhum arquivo alterado.' }
# Evita buscar um manifesto inexistente para catálogos externos.
$antigoTry = "    try {`n      final manifest = await addons.getManifest(entry.addon);"
$novoTry = "    try {`n      if (!item.id.startsWith('tvmaze:') && !item.id.startsWith('mal:')) {`n      final manifest = await addons.getManifest(entry.addon);"
if ($trecho.Contains("`r`n")) {
  $antigoTry = $antigoTry.Replace("`n", "`r`n")
  $novoTry = $novoTry.Replace("`n", "`r`n")
}
if (-not $trecho.Contains($antigoTry)) { throw 'Bloco de manifesto diferente do esperado. Nenhum arquivo alterado.' }
$trecho = $trecho.Replace($antigoTry, $novoTry)
$fechoAntigo = "    } catch (_) {"
$fechoNovo = "      }`n    } catch (_) {"
if ($trecho.Contains("`r`n")) { $fechoNovo = $fechoNovo.Replace("`n", "`r`n") }
if (-not $trecho.Contains($fechoAntigo)) { throw 'Fechamento do try nao encontrado. Nenhum arquivo alterado.' }
$trecho = $trecho.Replace($fechoAntigo, $fechoNovo)
if ($trecho.Contains("`r`n")) { $marcadorInsercao = $marcadorInsercao.Replace("`n", "`r`n"); $marcadorMetodo = $marcadorMetodo.Replace("`n", "`r`n") }
$trecho = $trecho.Replace($marcadorMetodo, $marcadorInsercao + $marcadorMetodo)
$codigoNovo = $codigo.Substring(0, $inicio) + $trecho + $codigo.Substring($fim)
if (-not $codigoNovo.Contains($import)) { $codigoNovo = $codigoNovo.Replace($marcadorImport, $marcadorImport + "`n" + $import) }
$backup = "$arquivo.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $arquivo $backup
[System.IO.File]::WriteAllText((Resolve-Path $arquivo).Path, $codigoNovo, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Integracao de episodios aplicada. Backup: $backup" -ForegroundColor Green
Write-Host 'Execute: dart format lib\screens\addon_category_screen.dart; flutter analyze'
