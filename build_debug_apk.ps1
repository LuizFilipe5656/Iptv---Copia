# Script PowerShell para gerar APK Debug do Cine Mobile
# Uso: .\build_debug_apk.ps1

param(
    [switch]$Clean,
    [switch]$Install,
    [string]$DeviceId,
    [switch]$Help
)

if ($Help) {
    Write-Host "Uso: .\build_debug_apk.ps1 [opções]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opções:" -ForegroundColor Yellow
    Write-Host "  -Clean      Limpa o build anterior antes de compilar"
    Write-Host "  -Install    Instala o APK no dispositivo conectado"
    Write-Host "  -DeviceId   ID específico do dispositivo para instalação"
    Write-Host "  -Help       Mostra esta ajuda"
    Write-Host ""
    Write-Host "Exemplos:" -ForegroundColor Yellow
    Write-Host "  .\build_debug_apk.ps1"
    Write-Host "  .\build_debug_apk.ps1 -Clean"
    Write-Host "  .\build_debug_apk.ps1 -Clean -Install"
    Write-Host "  .\build_debug_apk.ps1 -Install -DeviceId emulator-5554"
    exit
}

# Define diretórios
$ProjectDir = Join-Path $PSScriptRoot "iptv_modular_flutter"
$ApkOutput = Join-Path $ProjectDir "build\app\outputs\flutter-apk\app-debug.apk"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Gerador de APK Debug - Cine Mobile" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Verifica se o diretório existe
if (-not (Test-Path $ProjectDir)) {
    Write-Host "[ERRO] Diretório do projeto não encontrado: $ProjectDir" -ForegroundColor Red
    Write-Host ""
    Read-Host "Pressione Enter para sair"
    exit 1
}

Write-Host "[INFO] Diretório do projeto: $ProjectDir" -ForegroundColor Green
Write-Host "[INFO] APK será gerado em: $ApkOutput" -ForegroundColor Green
Write-Host ""

# Verifica se o Flutter está instalado
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCommand) {
    Write-Host "[ERRO] Flutter não encontrado no PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "Por favor, instale o Flutter:" -ForegroundColor Yellow
    Write-Host "1. Baixe em: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor White
    Write-Host "2. Extraia para: C:\flutter" -ForegroundColor White
    Write-Host "3. Adicione C:\flutter\bin ao PATH do sistema" -ForegroundColor White
    Write-Host ""
    Read-Host "Pressione Enter para sair"
    exit 1
}

Write-Host "[INFO] Flutter encontrado em: $($flutterCommand.Source)" -ForegroundColor Green
Write-Host ""

# Navega para o diretório do projeto
Set-Location $ProjectDir

# Limpa build se solicitado
if ($Clean) {
    Write-Host "[INFO] Limpando build anterior..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERRO] Falha ao limpar build." -ForegroundColor Red
        Read-Host "Pressione Enter para sair"
        exit 1
    }
    Write-Host "[OK] Build limpo com sucesso." -ForegroundColor Green
}

# Instala dependências
Write-Host "[INFO] Instalando dependências..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Falha ao instalar dependências." -ForegroundColor Red
    Read-Host "Pressione Enter para sair"
    exit 1
}
Write-Host "[OK] Dependências instaladas com sucesso." -ForegroundColor Green

# Gera APK Debug
Write-Host ""
Write-Host "[INFO] Gerando APK Debug..." -ForegroundColor Yellow
Write-Host "[INFO] Isso pode levar alguns minutos na primeira compilação..." -ForegroundColor Yellow
Write-Host ""

$sw = [Diagnostics.Stopwatch]::StartNew()
flutter build apk --debug
$sw.Stop()

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Falha ao gerar APK." -ForegroundColor Red
    Read-Host "Pressione Enter para sair"
    exit 1
}

Write-Host ""
Write-Host "[OK] APK gerado em $($sw.Elapsed.ToString('mm\:ss'))" -ForegroundColor Green

# Verifica se o APK foi gerado
if (Test-Path $ApkOutput) {
    $apkSize = (Get-Item $ApkOutput).Length
    $apkSizeMB = [math]::Round($apkSize / 1MB, 2)

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "[SUCESSO] APK gerado com sucesso!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Localização: $ApkOutput" -ForegroundColor White
    Write-Host "Tamanho: $apkSizeMB MB" -ForegroundColor White
    Write-Host ""

    # Pergunta se quer abrir o diretório
    $openDir = Read-Host "Deseja abrir o diretório do APK? (S/N)"
    if ($openDir -eq "S" -or $openDir -eq "s") {
        explorer (Split-Path $ApkOutput)
    }

    # Instala no dispositivo se solicitado
    if ($Install) {
        Write-Host ""
        Write-Host "[INFO] Verificando dispositivos conectados..." -ForegroundColor Yellow
        flutter devices
        Write-Host ""

        if ([string]::IsNullOrEmpty($DeviceId)) {
            Write-Host "[INFO] Instalando no primeiro dispositivo disponível..." -ForegroundColor Yellow
            flutter install
        } else {
            Write-Host "[INFO] Instalando no dispositivo: $DeviceId" -ForegroundColor Yellow
            flutter install -d $DeviceId
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERRO] Falha ao instalar APK." -ForegroundColor Red
        } else {
            Write-Host "[OK] APK instalado com sucesso." -ForegroundColor Green
        }
    }
} else {
    Write-Host "[ERRO] APK não encontrado no local esperado." -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifique se houve erros durante a compilação." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Processo concluído." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Pressione Enter para sair"
