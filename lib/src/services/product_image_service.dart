import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diagnostic_service.dart';

/// Product photos, kept on the device and owned by the app.
///
/// ## Why the stored path is relative
///
/// `product.image_path` holds `product_images/<name>.jpg`, never an absolute
/// path. An app's sandbox directory is not stable: it differs between
/// devices, and Android can change it across a reinstall. A backup restored
/// onto a new phone would carry absolute paths pointing at a directory that
/// no longer exists, so every photo in the catalogue would break at once.
/// A relative path survives that, because the base is resolved fresh each
/// time the app starts.
///
/// ## Why photos are downscaled on the way in
///
/// A modern phone camera produces 3–8 MB per shot. A shop with 400 products
/// would hold a couple of gigabytes, and the backup archive — which has to
/// be small enough to send over WhatsApp — would become unusable. The
/// picker is asked for at most [_maxDimension] on the long edge at
/// [_quality], which lands around 100–200 KB: ample for recognising a
/// packet on a shelf, which is the entire job.
class ProductImageService {
  ProductImageService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Directory name inside the app's support directory, and the first
  /// segment of every stored path.
  static const String directoryName = 'product_images';

  static const double _maxDimension = 1200;
  static const int _quality = 78;

  /// Resolved once at startup. Held statically so widgets can turn a stored
  /// relative path into a file during `build`, which cannot await.
  static Directory? _baseDirectory;

  /// Called once before the first frame, and by tests with a temp directory.
  static Future<Directory> initialise({Directory? override}) async {
    final base = override ?? await getApplicationSupportDirectory();
    _baseDirectory = base;
    return base;
  }

  /// The app support directory, or null before [initialise] has run.
  static Directory? get baseDirectory => _baseDirectory;

  /// Turns a stored relative path into a file.
  ///
  /// Returns null when there is no photo, or before the base directory is
  /// known — a caller that gets null shows its fallback, which is what it
  /// would do for a missing file anyway.
  static File? resolve(String? storedPath) {
    final base = _baseDirectory;
    final relative = storedPath?.trim();
    if (base == null || relative == null || relative.isEmpty) return null;
    // An absolute path should never be stored, but a database written by a
    // build that did is still readable: use it as-is rather than gluing it
    // onto the base and producing nonsense.
    if (p.isAbsolute(relative)) return File(relative);
    return File(p.join(base.path, relative));
  }

  Future<Directory> _imagesDirectory() async {
    final base = _baseDirectory ?? await initialise();
    final dir = Directory(p.join(base.path, directoryName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Takes a photo or picks one, stores it, and returns the relative path.
  ///
  /// Returns null if the user backed out, which is an ordinary outcome and
  /// not an error.
  Future<String?> capture({
    required ImageSource source,
    required int productId,
  }) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _quality,
      );
    } catch (error) {
      DiagnosticService.instance.log(
        'Picking a product photo failed: $error',
        level: 'WARN',
      );
      rethrow;
    }
    if (picked == null) return null;

    return store(File(picked.path), productId: productId);
  }

  /// Copies [source] into the app's own directory and returns the relative
  /// path to store.
  ///
  /// The name carries the product id and a timestamp rather than being the
  /// id alone: overwriting a file the image cache has already decoded shows
  /// the previous photo until the cache is evicted, which looks exactly
  /// like the new one failing to save.
  Future<String> store(File source, {required int productId}) async {
    final dir = await _imagesDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(source.path).toLowerCase();
    final name = 'p${productId}_$stamp'
        '${extension.isEmpty ? '.jpg' : extension}';
    final destination = File(p.join(dir.path, name));
    await source.copy(destination.path);
    return p.join(directoryName, name);
  }

  /// Removes a stored photo, if it is still there.
  ///
  /// Never throws: a photo that has already gone is the state the caller
  /// wanted, and failing to delete one must not block the edit that asked
  /// for it.
  Future<void> delete(String? storedPath) async {
    final file = resolve(storedPath);
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      DiagnosticService.instance.log(
        'Could not delete a product photo: $error',
        level: 'WARN',
      );
    }
  }

  /// Every stored photo, for the backup archive.
  static Future<List<File>> allImages() async {
    final base = _baseDirectory;
    if (base == null) return const [];
    final dir = Directory(p.join(base.path, directoryName));
    if (!await dir.exists()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => !p.basename(f.path).startsWith('.'))
        .toList();
  }

  /// Writes one photo back out of a backup archive.
  static Future<File> restoreImage(String name, List<int> bytes) async {
    final base = _baseDirectory ?? await initialise();
    final dir = Directory(p.join(base.path, directoryName));
    if (!await dir.exists()) await dir.create(recursive: true);
    // Only the basename is used: an archive naming an entry
    // "../../something" must not be able to write outside this directory.
    final destination = File(p.join(dir.path, p.basename(name)));
    await destination.writeAsBytes(bytes, flush: true);
    return destination;
  }
}
