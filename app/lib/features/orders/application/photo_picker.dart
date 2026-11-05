import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.contentType,
    this.name,
  });

  final Uint8List bytes;
  final String contentType;
  final String? name;
}

abstract class PhotoPicker {
  Future<PickedPhoto?> pick();
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final contentType =
        file.mimeType ?? _contentTypeFromName(file.name) ?? 'image/jpeg';

    return PickedPhoto(bytes: bytes, contentType: contentType, name: file.name);
  }
}

String? _contentTypeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return null;
}

final photoPickerProvider = Provider<PhotoPicker>((ref) {
  return ImagePickerPhotoPicker();
});
