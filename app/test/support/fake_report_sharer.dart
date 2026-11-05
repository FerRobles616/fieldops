import 'dart:typed_data';

import 'package:fieldops_app/features/orders/application/report_sharer.dart';

class FakeReportSharer implements ReportSharer {
  int calls = 0;
  Uint8List? lastBytes;
  String? lastFilename;

  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
  }) async {
    calls++;
    lastBytes = bytes;
    lastFilename = filename;
  }
}
