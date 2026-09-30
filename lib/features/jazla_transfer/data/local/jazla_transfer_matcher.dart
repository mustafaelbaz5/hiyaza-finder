import '../../../cities/data/model/association_type.dart';
import '../model/jazla_transfer_manifest.dart';

class JazlaTransferMatcher {
  const JazlaTransferMatcher();

  String? mismatch({
    required final JazlaTransferManifest manifest,
    required final String cityId,
    required final String cityName,
    required final String? associationName,
    required final String? associationCode,
    required final AssociationType? associationType,
  }) {
    if (manifest.cityId != cityId) return 'jazla.transfer.error_city_mismatch';
    if (associationType == null ||
        associationType != manifest.association.type) {
      return 'jazla.transfer.error_association_mismatch';
    }
    final String currentName = associationName?.trim() ?? '';
    if (currentName.isEmpty ||
        normalize(currentName) != normalize(manifest.association.name)) {
      return 'jazla.transfer.error_association_mismatch';
    }
    final String sourceCode = manifest.association.code?.trim() ?? '';
    final String currentCode = associationCode?.trim() ?? '';
    if (sourceCode.isNotEmpty &&
        currentCode.isNotEmpty &&
        sourceCode != currentCode) {
      return 'jazla.transfer.error_association_mismatch';
    }
    return null;
  }

  String normalize(final String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ');
}
