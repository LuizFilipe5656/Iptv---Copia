# Gerar APK Debug - Cine Mobile

Scripts automatizados para gerar APK debug do projeto Flutter.

## 📱 Scripts Disponíveis

### 1. build_debug_apk.bat (CMD/Command Prompt)
Script batch tradicional para Windows CMD.

### 2. build_debug_apk.ps1 (PowerShell)
Script PowerShell mais avançado com parâmetros.

## 🚀 Como Usar

### Opção 1: Script Batch (.bat)

1. Dê duplo clique em `build_debug_apk.bat`
2. Siga as instruções no prompt
3. O script irá:
   - Verificar se o Flutter está instalado
   - Perguntar se quer limpar o build anterior
   - Instalar dependências
   - Gerar o APK debug
   - Perguntar se quer abrir o diretório
   - Perguntar se quer instalar no dispositivo conectado

### Opção 2: Script PowerShell (.ps1)

```powershell
# Básico
.\build_debug_apk.ps1

# Limpar build antes
.\build_debug_apk.ps1 -Clean

# Gerar e instalar no dispositivo
.\build_debug_apk.ps1 -Clean -Install

# Instalar em dispositivo específico
.\build_debug_apk.ps1 -Install -DeviceId emulator-5554

# Mostrar ajuda
.\build_debug_apk.ps1 -Help
```

## 📋 Pré-requisitos

### 1. Flutter Instalado
- Baixe em: https://docs.flutter.dev/get-started/install/windows
- Extraia para: `C:\flutter`
- Adicione `C:\flutter\bin` ao PATH do sistema

### 2. Verificar Instalação
```powershell
flutter doctor
```

### 3. Dispositivo Android (opcional)
- Emulador Android ou dispositivo físico
- Depuração USB habilitada
- ADB configurado

## 📦 Localização do APK

O APK será gerado em:
```
C:\Users\Fredson\Documents\Iptv\iptv_modular_flutter\build\app\outputs\flutter-apk\app-debug.apk
```

## ⏱️ Tempo Estimado

- **Primeira compilação**: 5-15 minutos
- **Compilações subsequentes**: 2-5 minutos
- **Com -Clean**: Adiciona 1-2 minutos

## 🔧 Solução de Problemas

### Flutter não encontrado
```
[ERRO] Flutter não encontrado no PATH.
```

**Solução**:
1. Instale o Flutter
2. Adicione `C:\flutter\bin` ao PATH
3. Reinicie o terminal
4. Execute `flutter doctor`

### Falha ao instalar dependências
```
[ERRO] Falha ao instalar dependências.
```

**Solução**:
1. Verifique sua conexão com a internet
2. Execute `flutter pub get` manualmente
3. Verifique se há erros no `pubspec.yaml`

### Falha ao gerar APK
```
[ERRO] Falha ao gerar APK.
```

**Solução**:
1. Execute `flutter doctor` para verificar dependências
2. Certifique-se de ter o Android SDK instalado
3. Execute com `-Clean` para limpar build anterior
4. Verifique os logs de erro

### Dispositivo não encontrado
```
[ERRO] Falha ao instalar APK.
```

**Solução**:
1. Execute `flutter devices` para listar dispositivos
2. Verifique se o dispositivo está conectado
3. Verifique se a depuração USB está habilitada
4. Use `-DeviceId` para especificar o dispositivo

## 📝 Antes de Testar

**Importante**: Antes de instalar o APK, execute os SQLs no Supabase:

1. **Admins**: Execute `supabase_admins_setup.sql` no SQL Editor
2. **Catálogos**: Execute `supabase_catalog_tables.sql` no SQL Editor

## 🎯 Opções Avançadas

### APK Release (para produção)
```powershell
flutter build apk --release
```

### APK Split por Arquitetura (tamanho menor)
```powershell
flutter build apk --debug --split-per-abi
```

### APK Específico por Arquitetura
```powershell
flutter build apk --debug --target-platform android-arm64
```

### APK com Assinatura (Google Play)
```powershell
flutter build apk --release
```
> Nota: Requer configuração de assinatura no `android/key.properties`

## 📊 Informações do APK

Após gerar, o script mostrará:
- Localização do arquivo
- Tamanho em MB
- Tempo de compilação

## 🔒 Notas de Segurança

- APK **debug** não deve ser distribuído publicamente
- Use APK **release** para produção
- Mantenha suas chaves de assinatura seguras
- Não commit chaves no repositório

## 🆘 Suporte

Para problemas específicos:
- Documentação Flutter: https://docs.flutter.dev
- Documentação Android: https://developer.android.com
- Stack Overflow: https://stackoverflow.com/questions/tagged/flutter
