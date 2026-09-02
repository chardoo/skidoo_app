/// Giving a wide photo a little more height on a tall screen.
///
/// A viewer boxes a photo to its own shape and centres it, which is the honest
/// thing to do — nothing is cropped and the overlays hug the real edges. On a
/// phone that is twice as tall as it is wide, though, "its own shape" means a
/// landscape frame fills the width and then stops: a 3:2 photo on a 390×557
/// stage is 260 points tall and sits in the middle of nearly three hundred
/// points of black. The photo is the entire reason the screen exists and it is
/// using under half of it.
///
/// There is no way to add height without taking width — the photo is already as
/// wide as the screen. So this trades a strip of the sides for a taller frame,
/// and both halves of that trade are bounded:
///
/// * It only acts on a photo that is genuinely short, [_shortBelow] of the
///   space it has. A 4:3 frame is not short and is left exactly as it was.
/// * It never takes more than [_maxCrop] of the width. That ceiling matters
///   more here than in most viewers: this is where somebody decides whether the
///   face in a crowd shot is theirs, and the answer can be standing at the
///   edge of the frame.
///
/// Returns the aspect ratio the box should use. Equal to [photoAspect] when
/// nothing should change, which the caller reads as "draw it contained" — see
/// [liftsPhoto].
library;

/// Below this fraction of the available height, a photo is short enough to be
/// worth lifting.
///
/// Half. Chosen so the shapes people actually shoot land on the right side of
/// it: 4:3 fills 53% of a phone-shaped stage and is left alone, while 3:2 and
/// anything wider fall under and get the lift.
const double _shortBelow = 0.5;

/// The most of the width this will ever take. A tenth is a strip; a third is a
/// different photograph.
const double _maxCrop = 0.12;

/// The aspect ratio to draw [photoAspect] at, given the room available.
///
/// [available] dimensions are the stage's, in the same units. A non-positive
/// or unusable box returns [photoAspect] untouched: there is nothing to
/// reason about, and guessing would be worse than leaving it.
double liftedAspect({
  required double photoAspect,
  required double availableWidth,
  required double availableHeight,
}) {
  if (photoAspect <= 0 || availableWidth <= 0 || availableHeight <= 0) {
    return photoAspect;
  }

  // What it would be drawn at now: width-bound, because the stage is taller
  // than it is wide for every landscape photo on a phone.
  final fittedHeight = availableWidth / photoAspect;
  if (fittedHeight >= availableHeight) return photoAspect;
  if (fittedHeight >= availableHeight * _shortBelow) return photoAspect;

  // As tall as the crop budget allows, and never taller than the stage.
  final tallestAllowed = availableWidth / (photoAspect * (1 - _maxCrop));
  final target = tallestAllowed < availableHeight * _shortBelow
      ? tallestAllowed
      : availableHeight * _shortBelow;

  // Only ever grows. A photo already taller than the target keeps its shape.
  if (target <= fittedHeight) return photoAspect;
  return availableWidth / target;
}

/// Whether [liftedAspect] would change this photo — and therefore whether the
/// image has to be drawn `cover` rather than `contain`.
///
/// A box that is not the photo's own shape with `contain` inside it is the
/// original letterbox with extra steps: the black moves inside the box instead
/// of around it, and nothing is gained.
bool liftsPhoto({
  required double photoAspect,
  required double availableWidth,
  required double availableHeight,
}) =>
    liftedAspect(
      photoAspect: photoAspect,
      availableWidth: availableWidth,
      availableHeight: availableHeight,
    ) !=
    photoAspect;
