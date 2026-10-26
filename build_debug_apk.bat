@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ============================================
echo Gerador de APK Debug - Cine Mobile
echo ============================================
echo.

REM Define o diretório do projeto
set PROJECT_DIR=%~dp0iptv_modular_flutter
set APK_OUTPUT=%PROJECT_DIR%\build\app\outputs\flutter-apk\app-debug.apk

REM Verifica se o diretório existe
if not exist "%PROJECT_DIR%" (
    echo [ERRO] Diretório do projeto não encontrado: %PROJECT_DIR%
    echo.
    pause
    exit /b 1
)

echo [INFO] Diretório do projeto: %PROJECT_DIR%
echo [INFO] APK será gerado em: %APK_OUTPUT%
echo.

REM Verifica se o Flutter está instalado
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Flutter não encontrado no PATH.
    echo.
    echo Por favor, instale o Flutter e adicione ao PATH:
    echo 1. Baixe em: https://docs.flutter.dev/get-started/install/windows
    echo 2. Extraia para: C:\flutter
    echo 3. Adicione C:\flutter\bin ao PATH do sistema
    echo.
    pause
    exit /b 1
)

echo [INFO] Flutter encontrado.
echo.

REM Navega para o diretório do projeto
cd /d "%PROJECT_DIR%"

REM Opção 1: Limpar build anterior
echo.
set /p CLEAN_BUILD="Deseja limpar o build anterior? (S/N): "
if /i "%CLEAN_BUILD%"=="S" (
    echo [INFO] Limpando build anterior...
    call flutter clean
    if %errorlevel% neq 0 (
        echo [ERRO] Falha ao limpar build.
        pause
        exit /b 1
    )
    echo [OK] Build limpo com sucesso.
)

REM Opção 2: Instalar dependências
echo.
echo [INFO] Instalando dependências...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao instalar dependências.
    pause
    exit /b 1
)
echo [OK] Dependências instaladas com sucesso.

REM Opção 3: Gerar APK Debug
echo.
echo [INFO] Gerando APK Debug...
echo [INFO] Isso pode levar alguns minutos na primeira compilação...
echo.

call flutter build apk --debug
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao gerar APK.
    pause
    exit /b 1
)

echo.
echo ============================================
echo [SUCESSO] APK gerado com sucesso!
echo ============================================
echo.
echo Localização: %APK_OUTPUT%
echo.

REM Verifica se o APK foi gerado
if exist "%APK_OUTPUT%" (
    echo [INFO] Tamanho do APK:
    for %%A in ("%APK_OUTPUT%") do echo %%~zA bytes
    echo.

    REM Pergunta se quer abrir o diretório
    set /p OPEN_DIR="Deseja abrir o diretório do APK? (S/N): "
    if /i "%OPEN_DIR%"=="S" (
        explorer "%PROJECT_DIR%\build\app\outputs\flutter-apk"
    )

    REM Pergunta se quer instalar no dispositivo conectado
    echo.
    set /p INSTALL="Deseja instalar no dispositivo Android conectado? (S/N): "
    if /i "%INSTALL%"=="S" (
        echo [INFO] Verificando dispositivos conectados...
        call flutter devices
        echo.
        set /p DEVICE_ID="Digite o ID do dispositivo (ou pressione Enter para o primeiro): "
        if "!DEVICE_ID!"=="" (
            call flutter install
        ) else (
            call flutter install -d !DEVICE_ID!
        )
        if %errorlevel% neq 0 (
            echo [ERRO] Falha ao instalar APK.
        ) else (
            echo [OK] APK instalado com sucesso.
        )
    )
) else (
    echo [ERRO] APK não encontrado no local esperado.
    echo.
    echo Verifique se houve erros durante a compilação.
)

echo.
echo ============================================
echo Processo concluído.
echo ============================================
echo.
pause
