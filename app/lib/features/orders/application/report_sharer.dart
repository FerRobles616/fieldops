import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

abstract class ReportSharer {
  Future<void> share({required Uint8List bytes, required String filename});
}

class SharePlusReportSharer implements ReportSharer {
  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/pdf', name: filename),
        ],
        downloadFallbackEnabled: true,
      ),
    );
  }
}

final reportSharerProvider = Provider<ReportSharer>((ref) {
  return SharePlusReportSharer();
});
