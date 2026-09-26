#!/usr/bin/env python3
"""Regenerate every app-icon PNG from the vector mark.

    python3 tool/generate_app_icon.py            # write the icons
    python3 tool/generate_app_icon.py --check    # verify, touch nothing
    python3 tool/generate_app_icon.py --field '#1D9E75' --mark '#F7F7F2'

The icons that shipped before this script were a small, soft raster blown up to
1024 — a JPEG's worth of ringing around every edge, the mark sitting a little
low and right of centre, on a white field the app uses nowhere. They had been
hand-exported once and then resized, which is why the large one looked wrong in
App Store Connect while the small ones looked merely dull.

Everything here comes from `assets/logo/jperg_icon_white.svg`, the same vector
the paid-photo watermark draws, so the icon cannot drift from the mark the app
itself uses. Re-run it after any change to that file.

## The composition

White field, mark in #1D9E75 — the logo as it is drawn everywhere else: on the
site's header, on the email template, on paper. The icons that shipped before
this script were white-backed too, and going green was a change nobody had
asked for; this puts the field back and keeps the part that was worth keeping,
which is that every size is now rendered from the vector rather than resized
from a soft raster.

The mark asset is named `_white` because it is drawn to be filled at the point
of use — the fill colour is an argument here, not a property of the file.

A green tile is one flag away (`--field '#1D9E75' --mark '#F7F7F2'`), and it is
not a bad icon: those are `logoBadgeBackground` / `logoTextColor` from
AppThemeExtension, the design system's own answer to the logo as a tile. It
just is not this app's icon.

The mark is 66% of the tile width, lifted 2.5% above centre. The lift is the
correction a triangle always needs: bounding-box centring puts a triangle's
mass low, and this mark's centre of mass sits 76 px below the middle of a
1024 px tile when its box is centred exactly. Half of that correction looks
centred; all of it looks top-heavy.

## Why not a dark field

Black would match the launch screen and the splash, which is a real argument.
It loses on the one thing an icon is for: the triangle's inner void is the
field colour showing through, so on black the shape reads as two loose wings
rather than one mark, and a dark tile has nothing to separate it from every
other dark tile on a home screen. White keeps the void reading as part of the
mark, which is how the logo is drawn.

## Requirements

Pillow, and macOS `qlmanage` as the SVG renderer (WebKit — no extra install).
The store rejects an icon with an alpha channel, so every file is written RGB.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / 'assets/logo/jperg_icon_white.svg'

# The mark's own coordinate space, from the file's viewBox. Its ink fills the
# box exactly, so the box is what gets centred.
VIEWBOX_W, VIEWBOX_H = 78.0, 62.0

FIELD = '#FFFFFF'
MARK = '#1D9E75'
WIDTH_FRACTION = 0.66
LIFT_FRACTION = 0.025

# Rendered once at this size and resampled down, rather than asking the
# renderer for 20 px directly: one high-resolution pass keeps every size
# identical in shape, and Lanczos is kinder to a thin diagonal than a
# rasteriser working with 20 pixels to spend.
MASTER = 2048

IOS_DIR = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
IOS_SIZES = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}

ANDROID_DIR = ROOT / 'android/app/src/main/res'
ANDROID_SIZES = {
    'mipmap-mdpi/ic_launcher.png': 48,
    'mipmap-hdpi/ic_launcher.png': 72,
    'mipmap-xhdpi/ic_launcher.png': 96,
    'mipmap-xxhdpi/ic_launcher.png': 144,
    'mipmap-xxxhdpi/ic_launcher.png': 192,
}


def compose(size: int, field: str, mark: str) -> str:
    """The icon as a standalone SVG: a filled tile with the mark laid on it."""
    paths = re.findall(r'<path d="([^"]+)"', SVG.read_text())
    if len(paths) != 2:
        sys.exit(f'{SVG.name}: expected 2 paths (the wings and the dot), '
                 f'found {len(paths)} — the mark has changed shape, so the '
                 f'framing below needs looking at rather than re-running.')

    scale = (size * WIDTH_FRACTION) / VIEWBOX_W
    drawn_w, drawn_h = VIEWBOX_W * scale, VIEWBOX_H * scale
    left = (size - drawn_w) / 2
    top = (size - drawn_h) / 2 - size * LIFT_FRACTION
    body = '\n'.join(f'<path d="{d}" fill="{mark}"/>' for d in paths)
    return (
        f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" '
        f'xmlns="http://www.w3.org/2000/svg">\n'
        f'<rect width="{size}" height="{size}" fill="{field}"/>\n'
        f'<g transform="translate({left:.3f},{top:.3f}) scale({scale:.6f})">\n'
        f'{body}\n</g>\n</svg>\n'
    )


def render_master(field: str, mark: str) -> Image.Image:
    """Rasterise the composed SVG via Quick Look, which is WebKit underneath."""
    if shutil.which('qlmanage') is None:
        sys.exit('qlmanage not found — this script needs macOS to rasterise '
                 'the SVG. Any other SVG renderer at 2048 px works too.')

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        svg = tmp / 'icon.svg'
        svg.write_text(compose(MASTER, field, mark))
        subprocess.run(
            ['qlmanage', '-t', '-s', str(MASTER), '-o', str(tmp), str(svg)],
            capture_output=True, check=True,
        )
        rendered = next(tmp.glob('*.png'), None)
        if rendered is None:
            sys.exit('qlmanage produced no thumbnail')
        master = Image.open(rendered).convert('RGB')

    if master.size != (MASTER, MASTER):
        sys.exit(f'expected a {MASTER}px square, got {master.size}')
    return master


def targets() -> list[tuple[Path, int]]:
    return (
        [(IOS_DIR / name, px) for name, px in IOS_SIZES.items()]
        + [(ANDROID_DIR / name, px) for name, px in ANDROID_SIZES.items()]
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--field', default=FIELD, help='tile colour')
    parser.add_argument('--mark', default=MARK, help='the mark drawn on it')
    parser.add_argument('--check', action='store_true',
                        help='report what is on disk; write nothing')
    args = parser.parse_args()

    if args.check:
        bad = 0
        for path, px in targets():
            if not path.exists():
                print(f'missing  {path.relative_to(ROOT)}')
                bad += 1
                continue
            with Image.open(path) as im:
                # Alpha is the one that matters: the store rejects the 1024
                # outright for it, and it is invisible until an upload fails.
                if im.size != (px, px) or im.mode != 'RGB':
                    print(f'wrong    {path.relative_to(ROOT)} '
                          f'{im.size} {im.mode} (want ({px}, {px}) RGB)')
                    bad += 1
        print('every icon is the right size and has no alpha channel'
              if not bad else f'{bad} problem(s)')
        return 1 if bad else 0

    master = render_master(args.field, args.mark)
    for path, px in targets():
        path.parent.mkdir(parents=True, exist_ok=True)
        master.resize((px, px), Image.LANCZOS).save(path, optimize=True)
        print(f'{px:>5}  {path.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
