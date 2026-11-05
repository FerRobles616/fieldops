import 'dart:typed_data';

enum PhotoSyncState {
  pending,
  uploaded,
  failed;

  static PhotoSyncState fromString(String value) {
    return switch (value) {
      'pending' => PhotoSyncState.pending,
      'uploaded' => PhotoSyncState.uploaded,
      'failed' => PhotoSyncState.failed,
      _ => PhotoSyncState.pending,
    };
  }

  String get value => switch (this) {
    PhotoSyncState.pending => 'pending',
    PhotoSyncState.uploaded => 'uploaded',
    PhotoSyncState.failed => 'failed',
  };
}

class WorkOrderPhoto {
  const WorkOrderPhoto({
    required this.id,
    required this.workOrderId,
    required this.contentType,
    required this.bytes,
    required this.state,
    required this.createdAt,
    this.remoteId,
    this.caption,
  });

  final String id;
  final String workOrderId;
  final String? remoteId;
  final String? caption;
  final String contentType;
  final Uint8List bytes;
  final PhotoSyncState state;
  final DateTime createdAt;

  bool get isPending => state == PhotoSyncState.pending;

  WorkOrderPhoto copyWith({String? remoteId, PhotoSyncState? state}) {
    return WorkOrderPhoto(
      id: id,
      workOrderId: workOrderId,
      remoteId: remoteId ?? this.remoteId,
      caption: caption,
      contentType: contentType,
      bytes: bytes,
      state: state ?? this.state,
      createdAt: createdAt,
    );
  }
}
