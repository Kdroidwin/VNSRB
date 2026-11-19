import 'dart:convert';

/// Checks the ZIP central directory before the archive library reads entries.
/// This bounds both metadata work and decompressed data from imported backups.
class FullBackupZipGuard {
  FullBackupZipGuard._();

  static const maxArchiveBytes = 128 * 1024 * 1024;
  static const maxEntries = 5000;
  static const maxEntryBytes = 32 * 1024 * 1024;
  static const maxManifestBytes = 64 * 1024 * 1024;
  static const maxTotalExpandedBytes = 256 * 1024 * 1024;

  static Map<String, int> inspect(List<int> bytes) {
    if (bytes.length < 22 || bytes.length > maxArchiveBytes) {
      throw const FormatException('Backup archive size is outside limits.');
    }

    final endRecord = _findEndRecord(bytes);
    if (endRecord < 0) throw const FormatException('Invalid ZIP archive.');
    if (_u16(bytes, endRecord + 4) != 0 ||
        _u16(bytes, endRecord + 6) != 0 ||
        _u16(bytes, endRecord + 8) != _u16(bytes, endRecord + 10)) {
      throw const FormatException('Multi-disk ZIP files are unsupported.');
    }

    final entryCount = _u16(bytes, endRecord + 10);
    final directoryBytes = _u32(bytes, endRecord + 12);
    final directoryOffset = _u32(bytes, endRecord + 16);
    if (entryCount == 0 ||
        entryCount > maxEntries ||
        directoryBytes == 0xffffffff ||
        directoryOffset == 0xffffffff ||
        directoryOffset + directoryBytes > endRecord) {
      throw const FormatException('ZIP directory is outside limits.');
    }

    final entries = <String, int>{};
    final localRanges = <({int start, int end})>[];
    var expandedBytes = 0;
    var cursor = directoryOffset;
    for (var index = 0; index < entryCount; index++) {
      _requireRange(bytes, cursor, 46);
      if (_u32(bytes, cursor) != 0x02014b50) {
        throw const FormatException('Invalid ZIP directory entry.');
      }

      final versionMadeBy = _u16(bytes, cursor + 4);
      final versionNeeded = _u16(bytes, cursor + 6);
      final flags = _u16(bytes, cursor + 8);
      final compression = _u16(bytes, cursor + 10);
      final compressedSize = _u32(bytes, cursor + 20);
      final expandedSize = _u32(bytes, cursor + 24);
      final centralCrc = _u32(bytes, cursor + 16);
      final nameBytes = _u16(bytes, cursor + 28);
      final extraBytes = _u16(bytes, cursor + 30);
      final commentBytes = _u16(bytes, cursor + 32);
      final diskNumber = _u16(bytes, cursor + 34);
      final externalAttributes = _u32(bytes, cursor + 38);
      final localHeaderOffset = _u32(bytes, cursor + 42);

      if (nameBytes == 0 ||
          nameBytes > 255 ||
          versionNeeded > 20 ||
          compressedSize == 0xffffffff ||
          expandedSize == 0xffffffff ||
          localHeaderOffset == 0xffffffff ||
          diskNumber != 0 ||
          localHeaderOffset >= directoryOffset ||
          (flags & ~0x0806) != 0 || // Only UTF-8 and DEFLATE option flags.
          compressedSize > maxArchiveBytes ||
          (compression == 0 && (flags & 0x0006) != 0) ||
          (compression != 0 && compression != 8)) {
        throw const FormatException('Unsupported or unsafe ZIP entry.');
      }

      final recordLength = 46 + nameBytes + extraBytes + commentBytes;
      _requireRange(bytes, cursor, recordLength);
      final name = utf8.decode(
        bytes.sublist(cursor + 46, cursor + 46 + nameBytes),
      );
      _validateEntryName(name, expandedSize);
      if (_hasZip64Extra(bytes, cursor + 46 + nameBytes, extraBytes)) {
        throw const FormatException('ZIP64 entries are unsupported.');
      }

      final operatingSystem = versionMadeBy >> 8;
      final unixMode = externalAttributes >> 16;
      if (operatingSystem == 3 && (unixMode & 0xf000) == 0xa000) {
        throw const FormatException('Symbolic links are unsupported.');
      }

      final localFlags = _u16(bytes, localHeaderOffset + 6);
      final localCompression = _u16(bytes, localHeaderOffset + 8);
      final localCrc = _u32(bytes, localHeaderOffset + 14);
      final localCompressedSize = _u32(bytes, localHeaderOffset + 18);
      final localExpandedSize = _u32(bytes, localHeaderOffset + 22);
      final localNameBytes = _u16(bytes, localHeaderOffset + 26);
      final localExtraBytes = _u16(bytes, localHeaderOffset + 28);
      _requireRange(bytes, localHeaderOffset, 30);
      if (_u32(bytes, localHeaderOffset) != 0x04034b50 ||
          localFlags != flags ||
          localCompression != compression ||
          localCrc != centralCrc ||
          localCompressedSize != compressedSize ||
          localExpandedSize != expandedSize ||
          localNameBytes != nameBytes ||
          localNameBytes > 255) {
        throw const FormatException('ZIP local and central headers disagree.');
      }
      final localHeaderLength = 30 + localNameBytes + localExtraBytes;
      _requireRange(bytes, localHeaderOffset, localHeaderLength);
      final localName = utf8.decode(
        bytes.sublist(
          localHeaderOffset + 30,
          localHeaderOffset + 30 + localNameBytes,
        ),
      );
      if (localName != name ||
          _hasZip64Extra(
            bytes,
            localHeaderOffset + 30 + localNameBytes,
            localExtraBytes,
          )) {
        throw const FormatException('Unsafe ZIP local entry.');
      }
      final localDataStart = localHeaderOffset + localHeaderLength;
      final localDataEnd = localDataStart + compressedSize;
      if (localDataEnd > directoryOffset) {
        throw const FormatException('ZIP file data overlaps its directory.');
      }
      localRanges.add((start: localHeaderOffset, end: localDataEnd));

      final isDirectory = name.endsWith('/');
      final perEntryLimit =
          name == 'backup.json' ? maxManifestBytes : maxEntryBytes;
      if (expandedSize > perEntryLimit ||
          (isDirectory && expandedSize != 0) ||
          expandedBytes > maxTotalExpandedBytes - expandedSize) {
        throw const FormatException('Expanded backup size is outside limits.');
      }
      expandedBytes += expandedSize;

      if (entries.containsKey(name)) {
        throw const FormatException('Duplicate ZIP entry.');
      }
      entries[name] = expandedSize;
      cursor += recordLength;
    }

    if (cursor != directoryOffset + directoryBytes ||
        !entries.containsKey('backup.json')) {
      throw const FormatException('Incomplete backup archive.');
    }
    localRanges.sort((a, b) => a.start.compareTo(b.start));
    for (var index = 1; index < localRanges.length; index++) {
      if (localRanges[index - 1].end > localRanges[index].start) {
        throw const FormatException('Overlapping ZIP file entries.');
      }
    }
    return entries;
  }

  static bool _hasZip64Extra(List<int> bytes, int offset, int length) {
    _requireRange(bytes, offset, length);
    final end = offset + length;
    while (offset < end) {
      if (end - offset < 4) {
        throw const FormatException('Malformed ZIP extra data.');
      }
      final id = _u16(bytes, offset);
      final fieldLength = _u16(bytes, offset + 2);
      offset += 4;
      if (offset + fieldLength > end) {
        throw const FormatException('Malformed ZIP extra data.');
      }
      if (id == 0x0001) return true;
      offset += fieldLength;
    }
    return false;
  }

  static void _validateEntryName(String name, int size) {
    if (name.isEmpty ||
        name.startsWith('/') ||
        name.contains('\\') ||
        name.contains('\u0000') ||
        name.contains(':')) {
      throw const FormatException('Unsafe ZIP entry name.');
    }
    final parts = name.split('/');
    if (parts.any((part) => part == '.' || part == '..')) {
      throw const FormatException('Unsafe ZIP entry path.');
    }
    if (name == 'backup.json') return;
    if (name == 'media/') return;
    if (parts.length != 2 ||
        parts.first != 'media' ||
        parts.last.isEmpty ||
        size == 0) {
      throw const FormatException('Unexpected file in backup archive.');
    }
  }

  static int _findEndRecord(List<int> bytes) {
    final earliest = (bytes.length - 22 - 65535).clamp(0, bytes.length);
    for (var offset = bytes.length - 22; offset >= earliest; offset--) {
      if (_u32(bytes, offset) != 0x06054b50) continue;
      final commentLength = _u16(bytes, offset + 20);
      if (offset + 22 + commentLength == bytes.length) return offset;
    }
    return -1;
  }

  static void _requireRange(List<int> bytes, int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > bytes.length) {
      throw const FormatException('Truncated ZIP archive.');
    }
  }

  static int _u16(List<int> bytes, int offset) {
    _requireRange(bytes, offset, 2);
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static int _u32(List<int> bytes, int offset) {
    _requireRange(bytes, offset, 4);
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }
}
