import 'package:fieldops_app/features/orders/application/photo_picker.dart';

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker(this.photo);

  final PickedPhoto? photo;
  int calls = 0;

  @override
  Future<PickedPhoto?> pick() async {
    calls++;
    return photo;
  }
}
