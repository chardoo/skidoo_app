import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';

/// Renders a locally-picked [XFile] image on every platform.
///
/// `Image.file` / `dart:io` are unavailable on Flutter web, where an
/// [XFile.path] is an opaque blob URL. So:
///   • web    → [Image.network] (the blob URL resolves directly)
///   • native → read the bytes once and show them via [Image.memory]
///
/// Mirrors the working selfie/face-capture preview pattern.
///
/// **Decodes to the size of the slot, not the size of the file.** A photo
/// straight off the camera is 12–48 MP; decoded at full resolution one costs
/// 50–200 MB of RAM (4 bytes a pixel) however small the thumbnail showing it
/// is, and a handful of them at once passes iOS's ~2 GB per-process ceiling
/// and gets the app killed mid-decode. [cacheWidth] fixes that: the decoder
/// downsamples on the way in, so the bitmap is only ever as big as what is on
/// screen.
class XFileImage extends StatelessWidget {
  const XFileImage(
    this.file, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final XFile file;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Physical-pixel width to decode to: the slot's logical width × the screen's
  /// pixel ratio, so the image is sharp but never larger than it can be shown.
  ///
  /// Falls back to 1080 when the slot is unbounded (a Row/Column with no
  /// width) — full-screen-ish, and still an order of magnitude under a raw
  /// camera frame.
  int _decodeWidth(BuildContext context, double? available) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logical = width ?? available;
    final target = (logical == null || !logical.isFinite || logical <= 0)
        ? 1080.0
        : logical;
    return (target * dpr).ceil().clamp(1, 4096);
  }

  Widget _image(BuildContext context, double? available) {
    final cacheWidth = _decodeWidth(context, available);
    if (kIsWeb) {
      return Image.network(file.path,
          width: width, height: height, fit: fit, cacheWidth: cacheWidth);
    }
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (_, snap) => snap.hasData
          ? Image.memory(snap.data!,
              width: width, height: height, fit: fit, cacheWidth: cacheWidth)
          : SizedBox(width: width, height: height),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A caller-supplied width already answers the question; only measure when
    // there isn't one, since LayoutBuilder costs a layout pass.
    if (width != null) return _image(context, width);
    return LayoutBuilder(
      builder: (context, constraints) => _image(
          context, constraints.maxWidth.isFinite ? constraints.maxWidth : null),
    );
  }
}
