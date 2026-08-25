import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Private, on-device image storage shared by Food Scan and Facial Scan —
/// each in its own subdirectory (never mixed, per the approved privacy
/// requirements) inside the app's own support directory, never a public
/// asset folder and never exposed to any other user or shared cache.
///
/// Every stored file gets a freshly generated name (timestamp + an
/// in-process counter) — the original picked filename is never used as
/// the file's identity on disk, so nothing about the source file (which
/// could itself carry identifying metadata) survives into storage naming.
class PrivateImageStore {
  PrivateImageStore._(this._dir);

  final Directory _dir;
  static int _counter = 0;

  /// [category] is `'food'` or `'facial'` — kept as separate physical
  /// subdirectories so the two scan types' images can never be listed or
  /// deleted through the wrong store.
  static Future<PrivateImageStore> forCategory(String category) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/private_scans/$category');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return PrivateImageStore._(dir);
  }

  /// Copies the file at [sourcePath] into private storage under a new
  /// generated filename and returns the new path. The source file (e.g. a
  /// path returned by the image picker, potentially in a shared/public
  /// temp location) is left untouched.
  Future<String> save(String sourcePath) async {
    final source = File(sourcePath);
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    final destPath = '${_dir.path}/$id.$ext';
    await source.copy(destPath);
    return destPath;
  }

  /// Deletes the file at [path] if it exists — a safe no-op if it was
  /// already removed (e.g. externally deleted), never an error.
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Whether the file at [path] still exists on disk — used to render an
  /// honest "image missing" state instead of a broken-image crash when a
  /// file was deleted outside the app.
  Future<bool> exists(String path) => File(path).exists();
}
