import 'package:flutter/material.dart';

import '../screens/player_screen.dart';
import '../services/localfiles_service.dart';

class LocalFilesScreen extends StatefulWidget {
  const LocalFilesScreen({
    super.key,
    this.service,
  });

  static const routeName = '/local-files';

  final LocalFilesService? service;

  @override
  State<LocalFilesScreen> createState() => _LocalFilesScreenState();
}

class _LocalFilesScreenState extends State<LocalFilesScreen> {
  late final LocalFilesService _files;
  late final List<LocalVideoFile> _selectedFiles;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _files = widget.service ?? const FilePickerLocalFilesService();
    _selectedFiles = [];
  }

  Future<void> _chooseFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final files = await _files.pickVideoFiles();
      if (mounted) {
        setState(() {
          _selectedFiles
            ..clear()
            ..addAll(files);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _play(LocalVideoFile file) {
    Navigator.pushNamed(
      context,
      PlayerScreen.routeName,
      arguments: PlayerLaunchRequest(
        url: file.path,
        contentId: '',
        isLocalFile: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arquivos locais')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _chooseFiles,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: const Text('Selecionar vídeos'),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Formatos aceitos: MP4, MKV e AVI.'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Não foi possível acessar os arquivos: $_error',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _selectedFiles.isEmpty
                ? const Center(child: Text('Nenhum vídeo selecionado.'))
                : ListView.separated(
                    itemCount: _selectedFiles.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      return ListTile(
                        leading: const Icon(Icons.video_file_outlined),
                        title: Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(file.extension.toUpperCase()),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () => _play(file),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
