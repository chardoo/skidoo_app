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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(file.path, width: width, height: height, fit: fit);
    }
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (_, snap) => snap.hasData
          ? Image.memory(snap.data!, width: width, height: height, fit: fit)
          : SizedBox(width: width, height: height),
    );
  }
}
