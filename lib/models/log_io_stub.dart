/// Web stub — 这些类型在 Web 上不会被实际使用（kIsWeb 守卫），
/// 仅为了让条件导入的默认分支能通过编译。
library log_io_stub;

// ignore_for_file: unused_element

class File extends FileSystemEntity {
  File(super.path);

  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<String> readAsString() async => '';
  void writeAsStringSync(String content, {FileMode? mode}) {}
  Future<void> writeAsString(String content, {FileMode? mode}) async {}
  Future<void> delete() async {}
  Future<FileStat> stat() async => FileStat(
        size: 0,
        type: FileType.notFound,
        changed: DateTime.now(),
        modified: DateTime.now(),
        accessed: DateTime.now(),
        modeChanged: DateTime.now(),
      );

  Directory get parent => Directory('/');
}

class Directory {
  final String path;
  Directory(this.path);

  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) async* {}
}

class FileMode {
  const FileMode._();

  static const FileMode append = FileMode._();
  static const FileMode write = FileMode._();
  static const FileMode read = FileMode._();
}

class FileStat {
  final int size;
  final FileType type;
  final DateTime changed;
  final DateTime modified;
  final DateTime accessed;
  final DateTime modeChanged;

  const FileStat({
    required this.size,
    required this.type,
    required this.changed,
    required this.modified,
    required this.accessed,
    required this.modeChanged,
  });
}

enum FileType { file, directory, link, notFound }

class FileSystemEntity {
  final String path;
  FileSystemEntity(this.path);
}
