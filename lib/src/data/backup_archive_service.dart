import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import 'backup_service.dart';

/// Portable backup archives — a single `.zip` the user owns.
///
/// Local snapshots protect against a bad update or a corrupt database. They do
/// not protect against the way a shopkeeper actually loses data: the phone.
/// Snapshots live in the app's private sandbox, so an uninstall, a factory
/// reset or a dropped handset destroys the database and every backup at once.
///
/// An archive is a plain zip the user can put anywhere — their own Drive,
/// WhatsApp, an SD card, a laptop. No backend, no account, no paid API, and
/// nothing that changes the "no data collected" Data Safety declaration.
/// It is also readable without StockSafe: unzip it and the SQLite file and a
/// human-readable manifest are right there.
class BackupArchiveService {
  const BackupArchiveService();

  static const String databaseEntry = 'stocksafe.sqlite';
  static const String manifestEntry = 'manifest.json';
  static const String readmeEntry = 'README.txt';

  /// Product photos live under this prefix inside the archive.
  static const String imagePrefix = 'images/';

  /// Bumped only if the archive layout changes in a way older builds cannot
  /// read. Independent of the database schema version.
  ///
  /// Still 1 with photos added: an older build reading a v2-era archive
  /// finds the database and manifest exactly where it expects them and
  /// ignores the extra entries, and a newer build reading an older archive
  /// simply finds no photos. Neither case is a failure, so refusing one
  /// would be a lie.
  static const int archiveFormatVersion = 1;

  static final DateFormat _fileDateFmt = DateFormat('yyyy-MM-dd_HHmmss');

  static String suggestedFileName([DateTime? now]) =>
      'stocksafe_backup_${_fileDateFmt.format(now ?? DateTime.now())}.zip';

  // ─── Export ───────────────────────────────────────────────────────

  /// Builds a zip from [databaseFile] and writes it to [destination].
  ///
  /// [databaseFile] must be a quiescent copy — a snapshot, or the live file
  /// with the connection closed. Zipping a database that is being written to
  /// captures a torn page.
  Future<File> writeArchive({
    required File databaseFile,
    required File destination,
    required int schemaVersion,
    Map<String, int> rowCounts = const {},
    List<File> images = const [],
  }) async {
    if (!await databaseFile.exists()) {
      throw ArgumentError('No database to archive: ${databaseFile.path}');
    }

    final bytes = await databaseFile.readAsBytes();
    final checksum = sha256.convert(bytes).toString();

    final archive = Archive()..add(ArchiveFile.bytes(databaseEntry, bytes));

    // Photos go in with the database. The database stores a path, not the
    // picture, so an archive without them restores a catalogue where every
    // product has lost its photo — silently, because the path is still
    // there. A product photo is the user's data like any other row.
    var imageBytes = 0;
    var imagesAdded = 0;
    for (final image in images) {
      if (!await image.exists()) continue;
      final data = await image.readAsBytes();
      archive.add(ArchiveFile.bytes('$imagePrefix${_basename(image.path)}', data));
      imageBytes += data.length;
      imagesAdded++;
    }

    final manifest = <String, dynamic>{
      'archiveFormatVersion': archiveFormatVersion,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'sha256': checksum,
      'rowCounts': rowCounts,
      'imageCount': imagesAdded,
      'imageBytes': imageBytes,
    };

    archive
      ..add(ArchiveFile.string(
        manifestEntry,
        const JsonEncoder.withIndent('  ').convert(manifest),
      ))
      ..add(ArchiveFile.string(readmeEntry, _readme(manifest)));

    final encoded = ZipEncoder().encode(archive);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(encoded, flush: true);
    return destination;
  }

  static String _readme(Map<String, dynamic> manifest) => '''
StockSafe backup
================

Created:        ${manifest['createdAt']}
Database schema: v${manifest['schemaVersion']}
Products:       ${(manifest['rowCounts'] as Map)['product'] ?? 'unknown'}
Movements:      ${(manifest['rowCounts'] as Map)['movement'] ?? 'unknown'}
Product photos: ${manifest['imageCount'] ?? 0}

To restore: open StockSafe, go to Backup, and choose "Import backup file".

$databaseEntry is an ordinary SQLite database. If StockSafe is ever
unavailable to you, any SQLite tool can open it and read your data. That is
deliberate — your records should not depend on this app continuing to exist.

Keep this file somewhere that is not only on your phone.

THIS FILE IS NOT PASSWORD PROTECTED
-----------------------------------
Anyone who opens it can read your full stock list, your buying and selling
prices, your profit margins, and your suppliers' names, phone numbers and
GSTINs.

That is on purpose: a password you forget would lock you out of your own
backup for good, which is the opposite of what a backup is for. The trade is
that you have to store the file somewhere only you can reach.

  Good:  your own cloud drive, your own computer, a USB stick you keep
  Risky: a shared computer, a group chat, a shared folder at work
''';

  // ─── Inspect ──────────────────────────────────────────────────────

  /// Reads and validates an archive without changing anything.
  ///
  /// Always call this before importing: it is the difference between telling
  /// the user what they are about to replace and finding out afterwards.
  Future<ArchiveInspection> inspect(File archiveFile) async {
    if (!await archiveFile.exists()) {
      return ArchiveInspection.invalid('That file no longer exists.');
    }

    final raw = await archiveFile.readAsBytes();

    // Check the zip signature before decoding. A decoder handed a text file
    // may return an empty archive rather than throwing, and the user would
    // then be told their backup is missing a database — true, but useless.
    // "This is not a zip" is the thing they can act on.
    if (!_hasZipHeader(raw)) {
      return ArchiveInspection.invalid(
        'That file is not a readable zip. Pick the .zip StockSafe exported.',
      );
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(raw);
    } catch (_) {
      return ArchiveInspection.invalid(
        'That zip could not be opened — it may have been truncated in transit. '
        'Try sending it again.',
      );
    }

    final dbEntry = archive.findFile(databaseEntry);
    if (dbEntry == null) {
      return ArchiveInspection.invalid(
        'This zip has no $databaseEntry in it, so it is not a StockSafe backup.',
      );
    }

    final dbBytes = dbEntry.readBytes();
    if (dbBytes == null || dbBytes.length < 100) {
      return ArchiveInspection.invalid('The database inside this backup is empty.');
    }

    if (!_hasSqliteHeader(dbBytes)) {
      return ArchiveInspection.invalid(
        'The file inside this backup is not a SQLite database.',
      );
    }

    final manifestEntryFile = archive.findFile(manifestEntry);
    if (manifestEntryFile == null) {
      return ArchiveInspection.invalid(
        'This backup has no manifest, so its contents cannot be verified.',
      );
    }

    Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestEntryFile.readBytes()!))
          as Map<String, dynamic>;
    } catch (_) {
      return ArchiveInspection.invalid('This backup has an unreadable manifest.');
    }

    final recorded = manifest['sha256'] as String?;
    if (recorded == null) {
      return ArchiveInspection.invalid('This backup records no checksum.');
    }
    if (sha256.convert(dbBytes).toString() != recorded) {
      return ArchiveInspection.invalid(
        'This backup is damaged — its contents do not match its checksum.',
      );
    }

    final schemaVersion = manifest['schemaVersion'];
    if (schemaVersion is! int) {
      return ArchiveInspection.invalid('This backup records no schema version.');
    }

    // Read from the archive rather than trusted from the manifest: the
    // count is shown to the user before they replace their data, and it
    // should describe what is actually in the file.
    final imageEntries = <String, List<int>>{};
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(imagePrefix)) continue;
      final data = file.readBytes();
      if (data == null) continue;
      imageEntries[_basename(file.name)] = data;
    }

    return ArchiveInspection.valid(
      schemaVersion: schemaVersion,
      createdAt: DateTime.tryParse(manifest['createdAt'] as String? ?? ''),
      rowCounts: <String, int>{
        for (final e in (manifest['rowCounts'] as Map? ?? {}).entries)
          e.key.toString(): (e.value as num).toInt(),
      },
      databaseBytes: dbBytes,
      images: imageEntries,
    );
  }

  /// Writes the database held inside an archive to [destination].
  Future<File> extractDatabase(
    ArchiveInspection inspection,
    File destination,
  ) async {
    final bytes = inspection.databaseBytes;
    if (bytes == null) {
      throw StateError('Cannot extract from an archive that failed inspection.');
    }
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    return destination;
  }

  /// The last path segment, whatever separators an archive happens to use.
  ///
  /// Zip entry names are attacker-controlled in the sense that matters
  /// here: a user can be sent any file. An entry called
  /// `images/../../../something` must not escape the images directory, and
  /// taking only the basename is what stops it.
  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;

  /// Local file header of a zip: `PK\x03\x04`. An empty zip starts `PK\x05\x06`.
  static bool _hasZipHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
  }

  static bool _hasSqliteHeader(Uint8List bytes) {
    const magic = 'SQLite format 3';
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic.codeUnitAt(i)) return false;
    }
    return true;
  }
}

/// The result of reading an archive, before anything has been changed.
class ArchiveInspection {
  const ArchiveInspection._({
    required this.isValid,
    this.error,
    this.schemaVersion,
    this.createdAt,
    this.rowCounts = const {},
    this.databaseBytes,
    this.images = const {},
  });

  factory ArchiveInspection.invalid(String reason) =>
      ArchiveInspection._(isValid: false, error: reason);

  factory ArchiveInspection.valid({
    required int schemaVersion,
    required DateTime? createdAt,
    required Map<String, int> rowCounts,
    required Uint8List databaseBytes,
    Map<String, List<int>> images = const {},
  }) =>
      ArchiveInspection._(
        isValid: true,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        rowCounts: rowCounts,
        databaseBytes: databaseBytes,
        images: images,
      );

  final bool isValid;

  /// Plain-language reason this archive cannot be used. Shown to the user, so
  /// it says what to do rather than what went wrong internally.
  final String? error;

  final int? schemaVersion;
  final DateTime? createdAt;
  final Map<String, int> rowCounts;
  final Uint8List? databaseBytes;

  /// Product photos found in the archive, by file name.
  final Map<String, List<int>> images;

  int get productCount => rowCounts['product'] ?? 0;
  int get movementCount => rowCounts['movement'] ?? 0;
  int get imageCount => images.length;

  /// Whether this build understands the archive's schema. A backup from a
  /// newer release carries columns this one has no migration for.
  bool isSupportedBy(int currentSchemaVersion) =>
      isValid && schemaVersion != null && schemaVersion! <= currentSchemaVersion;

  /// A one-line summary for the confirmation dialog, so the user can tell
  /// whether this is the backup they meant before replacing anything.
  String describe() {
    if (!isValid) return error ?? 'Unreadable backup.';
    final when = createdAt == null
        ? 'unknown date'
        : DateFormat.yMMMd().add_jm().format(createdAt!);
    final photos = imageCount == 0
        ? ''
        : ', $imageCount ${imageCount == 1 ? 'photo' : 'photos'}';
    return '$productCount products and $movementCount stock movements'
        '$photos, backed up $when.';
  }
}

/// Convenience: the manifest fields a [BackupService] snapshot records, in the
/// shape [BackupArchiveService.writeArchive] expects.
Map<String, int> rowCountsFrom(SnapshotManifest? manifest) =>
    manifest?.rowCounts ?? const {};
