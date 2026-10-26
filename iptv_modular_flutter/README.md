# Cine Mobile

Aplicativo Flutter para descobrir e assistir filmes, séries, animes e desenhos
por meio de catálogos e addons Stremio.

## Requisitos

- Flutter instalado e disponível no `PATH`.
- Um dispositivo ou emulador configurado para a plataforma desejada.
- Para Android, Android Studio e Android SDK instalados e configurados.

Confira a configuração do ambiente com:

```powershell
flutter doctor
```

## Instalação

No PowerShell, navegue até a raiz do projeto e instale as dependências:

```powershell
cd C:\Users\Fredson\Documents\Iptv\iptv_modular_flutter
flutter pub get
```

Para iniciar o aplicativo:

```powershell
flutter run
```

## Navegação e conteúdo

A navegação principal contém **Início**, **Descobrir**, **Add-ons** e
**Configurações**. A Home exibe o destaque, itens em andamento e catálogos de
filmes, séries, animes e desenhos. A busca pode consultar os catálogos dos
addons instalados.

Os addons fixos são instalados automaticamente de `assets/default_addons.json`:
Cinemeta, YouTube, Public Domain Movies, OpenSubtitles V3, FrostStream e
FenixFlix. Também é possível instalar addons Stremio personalizados. O app lê
os recursos declarados no manifest e consulta os recursos compatíveis; um addon
sem fontes de reprodução continua disponível para seus catálogos e metadados.

Itens dos catálogos abrem uma tela de detalhes antes da busca por fontes. O
player usa BetterPlayer para reproduzir streams de addons e arquivos locais
compatíveis com os codecs do dispositivo.

## YouTube

A tela YouTube permite pesquisar trailers oficiais, clipes e lives. Os
resultados são abertos no app ou navegador oficial do YouTube; o app não
incorpora nem baixa vídeos do serviço.

## WatchHub

Nos detalhes de um filme ou série, **Onde assistir no WatchHub** consulta
catálogos disponíveis no país atendido pelo serviço e separa assinaturas,
aluguel/compra e opções grátis. Toque em um serviço para abrir sua página
oficial. Disponibilidade e links são fornecidos pelo WatchHub e podem mudar.

## Arquivos locais

Selecione vídeos locais nos formatos MP4, MKV ou AVI pela opção **Arquivos
locais** nas configurações. A reprodução depende dos codecs disponíveis no
sistema; AVI e algumas combinações de codecs podem não ser suportados pelo
player do dispositivo.

## Verificação

Execute a análise estática e os testes:

```powershell
flutter analyze
flutter test
```

## Estrutura

- `lib/main.dart`: ponto de entrada e configuração do aplicativo.
- `lib/screens/`: telas de catálogo, detalhes, busca e gerenciamento.
- `lib/models/`: modelos de addons, metadados e reprodução.
- `lib/repositories/`: carregamento de manifests, catálogos e streams Stremio.
- `lib/services/`: serviços de addons, reprodução e recursos externos.
- `lib/widgets/`: componentes de apresentação reutilizáveis.
- `assets/default_addons.json`: addons fixos instalados por padrão.
