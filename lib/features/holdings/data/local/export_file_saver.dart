import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Where an export ended up, so the caller can decide whether to still
/// offer the OS share sheet (only meaningful once a real file exists on
/// disk).
class ExportSaveResult {
  const ExportSaveResult({required this.filePath, required this.userChoseLocation});

  final String filePath;

  /// `true` if this came from the user's own "Save As" pick;
  /// `false` if they cancelled the picker and this is the app-private
  /// fallback location instead.
  final bool userChoseLocation;
}

/// Lets the user pick where to save an export via the OS's native "Save
/// As" dialog (`FilePicker.platform.saveFile`) — Downloads, an SD card,
/// a cloud-synced folder, wherever they have access to, rather than the
/// export always landing silently in the app's private documents
/// directory. Falls back to that private directory (still usable via the
/// Share sheet afterward) if the user cancels the picker.
Future<ExportSaveResult> saveExportFile({
  required final Uint8List bytes,
  required final String fileName,
}) async {
  // `saveFile`'s `bytes` param writes the file directly on platforms that
  // support it (Android via SAF, iOS, desktop); where it isn't supported
  // it just returns the chosen path and the caller must write the bytes
  // itself — covering both cases here rather than assuming one.
  final String? pickedPath = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: const <String>['xlsx'],
  );

  if (pickedPath != null) {
    final File pickedFile = File(pickedPath);
    if (!await pickedFile.exists() || await pickedFile.length() == 0) {
      await pickedFile.writeAsBytes(bytes, flush: true);
    }
    return ExportSaveResult(filePath: pickedPath, userChoseLocation: true);
  }

  // User cancelled the picker (or the platform returned null outright) —
  // fall back to the app's own documents directory so the export still
  // exists somewhere and can be shared from there.
  final Directory dir = await getApplicationDocumentsDirectory();
  final File file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return ExportSaveResult(filePath: file.path, userChoseLocation: false);
}
