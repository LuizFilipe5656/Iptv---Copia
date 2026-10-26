import 'package:file_picker/file_picker.dart';

class LocalVideoFile {
  const LocalVideoFile({
    required this.name,
    required this.path,
    required this.extension,
  });

  static const supportedExtensions = {'mp4', 'mkv', 'avi'};

  factory LocalVideoFile.fromPath(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final separator = name.lastIndexOf('.');
    final extension =
        separator < 0 ? '' : name.substring(separator + 1).toLowerCase();
    if (!supportedExtensions.contains(extension)) {
      throw FormatException('Formato de vídeo não suportado: $extension.');
    }
    if (path.trim().isEmpty) {
      throw const FormatException('O caminho do arquivo não pode ser vazio.');
    }

    return LocalVideoFile(name: name, path: path, extension: extension);
  }

  final String name;
  final String path;
  final String extension;
}

abstract interface class LocalFilesService {
  Future<List<LocalVideoFile>> pickVideoFiles();
}

class FilePickerLocalFilesService implements LocalFilesService {
  const FilePickerLocalFilesService();

  @override
  Future<List<LocalVideoFile>> pickVideoFiles() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: LocalVideoFile.supportedExtensions.toList(),
    );
    if (file == null) {
      return const [];
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw FormatException(
        'Não foi possível acessar o caminho local de "${file.name}".',
      );
    }
    return [LocalVideoFile.fromPath(path)];
  }
}
