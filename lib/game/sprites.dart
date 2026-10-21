import 'dart:ui' as ui;

import 'shop.dart';

/// The bunny's pixel art, built into small images and drawn with nearest-neighbour sampling
/// so each sprite pixel stays a crisp square at any scale. Each skin's images are built the
/// first time they're needed.
class Sprites {
  Sprites()
      : ghost = _build(_ghostRows, _ghostPalette),
        hollow = BunnySprites._(_hollowPalette, rows: _hollowRows, wings: _hollowWingRows);

  /// The last run's crash marker: the bunny with X eyes, in see-through blues.
  final ui.Image ghost;

  /// A Hollow One: Pip's own shape gone wrong. One ear torn and flopped over, one glowing red
  /// eye and a button sewn on for the other, a stitched grin full of teeth, stitches across the
  /// chest, and tattered wings full of holes.
  final BunnySprites hollow;
  final Map<String, BunnySprites> _skins = {};

  /// Pip in [skin], marked by the [memories] it has got back (0 for the clean look, as in the
  /// shop): every memory greys the fur a little, and at 4, 8, 12 and 16 a new mark appears.
  BunnySprites skin(BunnySkin skin, {int memories = 0}) {
    final m = memories.clamp(0, 20);
    return _skins.putIfAbsent('${skin.id}/$m', () {
      final level = m ~/ 4;
      return BunnySprites._(_worn(skin.palette, m / 20),
          rows: _marked(level), wings: level >= 2 ? _tornWingRows : _wingRows);
    });
  }

  /// How many marks Pip carries for [memories] found: 0 to 5.
  static int marksFor(int memories) => memories.clamp(0, 20) ~/ 4;

  /// [palette] greyed and dimmed by [worn] (0 to 1), plus the colours of the marks.
  static Map<String, ui.Color> _worn(Map<String, ui.Color> palette, double worn) {
    const grey = ui.Color(0xFF6E6872);
    return {
      for (final MapEntry(:key, :value) in palette.entries)
        key: key == 'k' ? value : ui.Color.lerp(value, grey, 0.6 * worn)!,
      's': const ui.Color(0xFF9A1C30), // stitches
      'o': const ui.Color(0xFF16101A), // a black button
      'x': const ui.Color(0xFFD8CCB8), // the thread holding it on
    };
  }

  /// Pip's rows with the marks of [level]: a stitch on the cheek (1), a torn ear (2), a button
  /// for an eye (3), stitches down the chest (4), and the other cheek split and sewn (5).
  static List<String> _marked(int level) {
    final rows = [for (final r in _bunnyRows) r.split('')];
    void set(int row, int col, String c) => rows[row][col] = c;
    if (level >= 1) {
      set(12, 13, 's');
      set(13, 12, 's');
      set(13, 14, 's');
    }
    if (level >= 2) {
      set(0, 4, '.');
      set(0, 5, '.');
      set(1, 4, 'k');
      set(1, 5, '.');
      set(2, 5, 'k');
    }
    if (level >= 3) {
      set(10, 11, 'x');
      set(10, 12, 'o');
      set(11, 11, 'o');
      set(11, 12, 'x');
      set(9, 11, 'o');
      set(9, 12, 'o');
    }
    if (level >= 4) {
      for (final (row, col) in const [(16, 7), (17, 8), (18, 7), (19, 8), (20, 7)]) {
        set(row, col, 's');
      }
    }
    if (level >= 5) {
      set(12, 2, 's');
      set(13, 3, 's');
      set(14, 4, 's');
    }
    return [for (final r in rows) r.join()];
  }

  void dispose() {
    ghost.dispose();
    hollow.dispose();
    for (final skin in _skins.values) {
      skin.dispose();
    }
    _skins.clear();
  }

  static List<String> _wingFrame(List<String> rows, {required bool up}) {
    final blank = '.' * rows.first.length;
    final pad = [for (var i = 0; i < 4; i++) blank];
    return up ? [...rows, ...pad] : [...pad, ...rows.reversed];
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

  // Same bunny with X eyes, for the last run's crash marker. Letters: k outline and eyes,
  // w fur, g belly, p inside of the ears, c cheeks, n nose, m mouth, b wings.
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

  // Letters for the Hollow One: k outline (blood red, so it shows in the dark), w ash-grey fur,
  // g belly, p inside of the ear, c cheeks, n nose, m mouth, t teeth, r the glowing eye, x the
  // button's thread, s stitches, b tattered wings.
  static const _hollowPalette = {
    'k': ui.Color(0xFF8E1A2C),
    'w': ui.Color(0xFF3A3238),
    'g': ui.Color(0xFF4C424A),
    'p': ui.Color(0xFF5E1822),
    'c': ui.Color(0xFF4A1E28),
    'n': ui.Color(0xFF2A0A10),
    'm': ui.Color(0xFF0C0306),
    't': ui.Color(0xFFE6DAC4),
    'r': ui.Color(0xFFFF4040),
    'x': ui.Color(0xFFD0C4B4),
    's': ui.Color(0xFFC0303E),
    'b': ui.Color(0xFF2C2228),
  };

  // Pip's sprite, gone wrong. Column 8, row 14 is the anchor, like Pip's.
  static const _hollowRows = [
    '...kkk..........',
    '..kwwwk.........',
    '..kwpwk...kkk...',
    '..kwpwk..kwwkkk.',
    '..kwpwk..kwpwwwk',
    '..kwpwk..kwpkkk.',
    '..kwpwk..kwpwk..',
    '..kwwwkkkkwwwk..',
    '.kwwwwwwwswwwwk.',
    'kwwwwwwwwswkkkwk',
    'kwwrrwwwwswkxkwk',
    'kwwrrwwwwwwkkkwk',
    'kwccwwwnnwwwccwk',
    'kwmtmtmtmtmtmtwk',
    '.kwmmmmmmmmmmwk.',
    '..kkwwwwwwwwkk..',
    '..kwwwwwwwwwwk..',
    '.kwkwwwggwwwkwk.',
    '.kwkwsggggswkwk.',
    '.kkkwwgsggwwkkk.',
    '..kwwwggsgwwwk..',
    '..kwwwwggwwwwk..',
    '..kwwkkkkkkwwk..',
    '..kppk....kppk..',
    '..kkkk....kkkk..',
  ];

  static const _hollowWingRows = [
    'kk.....',
    'kbkk...',
    'kb.bkk.',
    '.kbb.bk',
    '..k.bbk',
    '...kk.k',
  ];

  // Pip's wings once the memories have worn them: holes torn through.
  static const _tornWingRows = [
    'kk.....',
    'kbkk...',
    'kb.bkk.',
    '.kbbb.k',
    '..kb.bk',
    '...kkkk',
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

/// One skin's bunny: the body, and two frames for each wing.
///
/// The bunny's anchor is the pixel at column 8, row 14 of [bunny]. The wing frames are 7x10
/// so the flap animation can swap them in place: the up frame sits at the top, the down
/// frame at the bottom.
class BunnySprites {
  BunnySprites._(Map<String, ui.Color> palette,
      {List<String> rows = Sprites._bunnyRows, List<String> wings = Sprites._wingRows})
      : bunny = Sprites._build(rows, palette),
        wingUpLeft = Sprites._build(Sprites._wingFrame(wings, up: true), palette),
        wingDownLeft = Sprites._build(Sprites._wingFrame(wings, up: false), palette),
        wingUpRight = Sprites._build(Sprites._wingFrame(wings, up: true), palette, flipX: true),
        wingDownRight = Sprites._build(Sprites._wingFrame(wings, up: false), palette, flipX: true);

  final ui.Image bunny, wingUpLeft, wingDownLeft, wingUpRight, wingDownRight;

  void dispose() {
    for (final image in [bunny, wingUpLeft, wingDownLeft, wingUpRight, wingDownRight]) {
      image.dispose();
    }
  }
}
