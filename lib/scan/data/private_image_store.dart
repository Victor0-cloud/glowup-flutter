import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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
///
/// On Web there is no real persistent filesystem to copy into (`dart:io`
/// File/Directory APIs are unsupported there), so this becomes a
/// deliberate pass-through: [save] returns the source path unchanged (a
/// `blob:` URL from image_picker's XFile, already valid for redisplay via
/// `ScanImagePreview` for the lifetime of the page) and [delete] is a safe
/// no-op — never a crash, and never an attempt at a fake persistent store.
class PrivateImageStore {
  PrivateImageStore._(this._dir);

  final Directory? _dir;
  static int _counter = 0;

  /// [category] is `'food'` or `'facial'` — kept as separate physical
  /// subdirectories so the two scan types' images can never be listed or
  /// deleted through the wrong store.
  static Future<PrivateImageStore> forCategory(String category) async {
    if (kIsWeb) return PrivateImageStore._(null);
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
  /// temp location) is left untouched. On Web, returns [sourcePath]
  /// unchanged (see class doc comment) — never touches `dart:io`.
  Future<String> save(String sourcePath) async {
    final dir = _dir;
    if (dir == null) return sourcePath;
    final source = File(sourcePath);
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    final destPath = '${dir.path}/$id.$ext';
    await source.copy(destPath);
    return destPath;
  }

  /// Deletes the file at [path] if it exists — a safe no-op if it was
  /// already removed (e.g. externally deleted), never an error. A no-op on
  /// Web, where nothing was ever copied into a real local store.
  Future<void> delete(String path) async {
    if (_dir == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Whether the file at [path] still exists on disk — used to render an
  /// honest "image missing" state instead of a broken-image crash when a
  /// file was deleted outside the app. Always true on Web (no local
  /// existence check makes sense for a `blob:` URL here).
  Future<bool> exists(String path) async {
    if (_dir == null) return true;
    return File(path).exists();
  }
}
