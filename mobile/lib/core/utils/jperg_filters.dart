import 'package:flutter/widgets.dart';

/// Shared colour-grade filters applied to feed media so photos and videos get
/// a consistent, vibrant "Instagram / TikTok" finish across the whole app.
///
/// All matrices preserve black levels (no flat brightness lift) so shadows stay
/// rich while colour and contrast are boosted — the opposite of the washed-out
/// look you get from naively adding a constant to every channel.
class JpergFilters {
  const JpergFilters._();

  /// Default feed polish: saturation ≈ 1.20, light contrast, a touch of warmth
  /// (red lifted, blue eased) for that golden-hour social-feed feel.
  ///
  /// Row layout is the standard 4×5 [ColorFilter.matrix] form:
  /// `[Rr Rg Rb Ra Roffset, Gr ... , Br ... , Ar ...]`.
  static const ColorFilter vibrant = ColorFilter.matrix(<double>[
    1.20, -0.12, -0.02, 0, 2, // R — saturated, slight warmth
    -0.07, 1.13, -0.02, 0, 0, // G
    -0.07, -0.13, 1.22, 0, -2, // B — eased for warmth, kept punchy
    0, 0, 0, 1, 0, // A
  ]);

  /// Gentler grade for already-bright content (e.g. light-mode surfaces) where
  /// the full [vibrant] look would clip highlights.
  static const ColorFilter crisp = ColorFilter.matrix(<double>[
    1.10, -0.06, -0.02, 0, 0,
    -0.04, 1.08, -0.02, 0, 0,
    -0.04, -0.07, 1.12, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}
