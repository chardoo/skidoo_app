import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:jperg_app/core/utils/image_pick.dart';

class _FakePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  int multiCalls = 0;
  int singleCalls = 0;
  int? lastLimit;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiCalls++;
    lastLimit = options.limit;
    return [XFile('a.jpg'), XFile('b.jpg')];
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    singleCalls++;
    return XFile('one.jpg');
  }
}

void main() {
  late _FakePicker fake;

  setUp(() {
    fake = _FakePicker();
    ImagePickerPlatform.instance = fake;
  });

  test('a limit of one uses the single picker', () async {
    // pickMultiImage throws ArgumentError below 2, so the pick that fills the
    // last slot — the one a capped picker exists for — used to crash.
    final picked = await pickImagesUpTo(ImagePicker(), limit: 1);

    expect(picked, hasLength(1));
    expect(fake.singleCalls, 1);
    expect(fake.multiCalls, 0);
  });

  test('two or more uses the multi picker, capped', () async {
    final picked = await pickImagesUpTo(ImagePicker(), limit: 5);

    expect(picked, hasLength(2));
    expect(fake.multiCalls, 1);
    expect(fake.lastLimit, 5);
  });

  test('no room left opens nothing', () async {
    expect(await pickImagesUpTo(ImagePicker(), limit: 0), isEmpty);
    expect(fake.multiCalls, 0);
    expect(fake.singleCalls, 0);
  });
}
