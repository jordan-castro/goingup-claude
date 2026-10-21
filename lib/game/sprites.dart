import 'dart:ui' as ui;

import 'palette.dart';

/// The bunny's pixel art, built once into small images and drawn with nearest-neighbour
/// sampling so each sprite pixel stays a crisp square at any scale.
///
/// The bunny's anchor is the pixel at column 8, row 14 of [bunny]. The wing frames are 7x10
/// so the flap animation can swap them in place: the up frame sits at the top, the down
/// frame at the bottom.
class Sprites {
  Sprites()
      : bunny = _build(_bunnyRows, _bunnyPalette),
        ghost = _build(_ghostRows, _ghostPalette),
        wingUpLeft = _build(_wingFrame(up: true), _bunnyPalette),
        wingDownLeft = _build(_wingFrame(up: false), _bunnyPalette),
        wingUpRight = _build(_wingFrame(up: true), _bunnyPalette, flipX: true),
        wingDownRight = _build(_wingFrame(up: false), _bunnyPalette, flipX: true);

  final ui.Image bunny, ghost, wingUpLeft, wingDownLeft, wingUpRight, wingDownRight;

  void dispose() {
    for (final image in [bunny, ghost, wingUpLeft, wingDownLeft, wingUpRight, wingDownRight]) {
      image.dispose();
    }
  }

  static List<String> _wingFrame({required bool up}) {
    final blank = '.' * _wingRows.first.length;
    final pad = [for (var i = 0; i < 4; i++) blank];
    return up ? [..._wingRows, ...pad] : [...pad, ..._wingRows.reversed];
  }

  static ui.Image _build(List<String> rows, Map<String, ui.Color> palette, {bool flipX = false}) {
    final h = rows.length, w = rows.first.length;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..isAntiAlias = false;
    for (var y = 0; y < h; y++) {
      final row = rows[y];
      for (var x = 0; x < w; x++) {
        final key = row[flipX ? w - 1 - x : x];
        final color = palette[key];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  static const _bunnyPalette = {
    'k': Palette.ink,
    'w': ui.Color(0xFFF6F4FA),
    'g': ui.Color(0xFFE0DAF0),
    'p': ui.Color(0xFFEEA4C8),
    'c': ui.Color(0xFFEC96BA),
    'n': ui.Color(0xFFDE608C),
    'm': ui.Color(0xFFA8527A),
    'b': ui.Color(0xFFC0E0F2),
  };

  static const _ghostPalette = {
    'k': ui.Color(0xFF6C7FD1),
    'w': ui.Color(0xFFE3ECFF),
    'g': ui.Color(0xFFC3D2FB),
    'p': ui.Color(0xFFD9B8FF),
    'c': ui.Color(0xFFD9B8FF),
    'n': ui.Color(0xFFB99CFF),
    'm': ui.Color(0xFF8A7FD8),
  };

  static const _bunnyRows = [
    '...kkk....kkk...',
    '..kwwwk..kwwwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwwwkkkkwwwk..',
    '.kwwwwwwwwwwwwk.',
    'kwwwwwwwwwwwwwwk',
    'kwwkkwwwwwwkkwwk',
    'kwwkkwwwwwwkkwwk',
    'kwccwwwnnwwwccwk',
    'kwwwwwwmmwwwwwwk',
    '.kwwwwmwwmwwwwk.',
    '..kkwwwwwwwwkk..',
    '..kwwwwwwwwwwk..',
    '.kwkwwwggwwwkwk.',
    '.kwkwwggggwwkwk.',
    '.kkkwwggggwwkkk.',
    '..kwwwggggwwwk..',
    '..kwwwwggwwwwk..',
    '..kwwkkkkkkwwk..',
    '..kppk....kppk..',
    '..kkkk....kkkk..',
  ];

  // Same bunny with X eyes, for the last run's crash marker.
  static const _ghostRows = [
    '...kkk....kkk...',
    '..kwwwk..kwwwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwpwk..kwpwk..',
    '..kwwwkkkkwwwk..',
    '.kwwwwwwwwwwwwk.',
    'kwkwkwwwwwwkwkwk',
    'kwwkwwwwwwwwkwwk',
    'kwkwkwwwwwwkwkwk',
    'kwccwwwnnwwwccwk',
    'kwwwwwwmmwwwwwwk',
    '.kwwwwmwwmwwwwk.',
    '..kkwwwwwwwwkk..',
    '..kwwwwwwwwwwk..',
    '.kwkwwwggwwwkwk.',
    '.kwkwwggggwwkwk.',
    '.kkkwwggggwwkkk.',
    '..kwwwggggwwwk..',
    '..kwwwwggwwwwk..',
    '..kwwkkkkkkwwk..',
    '..kppk....kppk..',
    '..kkkk....kkkk..',
  ];

  static const _wingRows = [
    'kk.....',
    'kbkk...',
    'kbbbkk.',
    '.kbbbbk',
    '..kbbbk',
    '...kkkk',
  ];
}
