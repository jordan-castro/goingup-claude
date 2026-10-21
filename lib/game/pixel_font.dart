import 'dart:ui';

/// Built-in 5x7 pixel font: A-Z, 0-9, a little punctuation (! ? & ' : . , - + % /), and the lowercase letters of
/// "going". Other lowercase letters fall back to capitals. Each glyph advances 6 pixels.
abstract final class PixelFont {
  // 7 rows of 5 cells per glyph, '#' = lit.
  static const Map<String, String> _glyphs = {
    'A': '.###.#...##...#######...##...##...#',
    'B': '####.#...##...#####.#...##...#####.',
    'C': '.###.#...##....#....#....#...#.###.',
    'D': '####.#...##...##...##...##...#####.',
    'E': '######....#....####.#....#....#####',
    'F': '######....#....####.#....#....#....',
    'G': '.###.#...##....#.####...##...#.####',
    'H': '#...##...##...#######...##...##...#',
    'I': '.###...#....#....#....#....#...###.',
    'J': '..###...#....#....#....#.#..#..##..',
    'K': '#...##..#.#.#..##...#.#..#..#.#...#',
    'L': '#....#....#....#....#....#....#####',
    'M': '#...###.###.#.##.#.##...##...##...#',
    'N': '#...##...###..##.#.##..###...##...#',
    'O': '.###.#...##...##...##...##...#.###.',
    'P': '####.#...##...#####.#....#....#....',
    'Q': '.###.#...##...##...##.#.##..#..##.#',
    'R': '####.#...##...#####.#.#..#..#.#...#',
    'S': '.#####....#.....###.....#....#####.',
    'T': '#####..#....#....#....#....#....#..',
    'U': '#...##...##...##...##...##...#.###.',
    'V': '#...##...##...##...##...#.#.#...#..',
    'W': '#...##...##...##.#.##.#.##.#.#.#.#.',
    'X': '#...##...#.#.#...#...#.#.#...##...#',
    'Y': '#...##...#.#.#...#....#....#....#..',
    'Z': '#####....#...#...#...#...#....#####',
    '0': '.###.#...##..###.#.###..##...#.###.',
    '1': '..#...##....#....#....#....#...###.',
    '2': '.###.#...#....#...#...#...#...#####',
    '3': '#####...#...#.....#.....##...#.###.',
    '4': '...#...##..#.#.#..#.#####...#....#.',
    '5': '######....####.....#....##...#.###.',
    '6': '..##..#...#....####.#...##...#.###.',
    '7': '#####....#...#...#...#....#....#...',
    '8': '.###.#...##...#.###.#...##...#.###.',
    '9': '.###.#...##...#.####....#...#..##..',
    '!': '..#....#....#....#....#.........#..',
    '?': '.###.#...#....#...#...#.........#..',
    '&': '.##..#..#.#.#...#...#.#.##..#..##.#',
    "'": '..#....#...#.......................',
    ':': '.......#....#.........#....#.......',
    '.': '..........................##...##..',
    ',': '.....................##....#...#...',
    '-': '................###................',
    '+': '.......#....#..#####..#....#.......',
    '%': '##...##..#...#...#...#...#..##...##',
    '/': '.........#...#...#...#...#.........',
    'g': '......#####...##...#.####....#.###.',
    'o': '...........###.#...##...##...#.###.',
    'i': '..#........##....#....#....#...###.',
    'n': '..........####.#...##...##...##...#',
  };

  static final Paint _paint = Paint()..isAntiAlias = false;

  /// Width of [text] when each font pixel is [px] units.
  static double widthOf(String text, double px) => text.isEmpty ? 0 : (text.length * 6 - 1) * px;

  /// [text] broken into lines of at most [maxChars] characters, between words.
  static List<String> wrap(String text, int maxChars) {
    final lines = <String>[];
    var line = '';
    for (final word in text.split(' ')) {
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= maxChars) {
        line = '$line $word';
      } else {
        lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  /// Glyph cells for [ch], or null for a space or an unknown character.
  static String? glyph(String ch) => _glyphs[ch] ?? _glyphs[ch.toUpperCase()];

  static void draw(Canvas canvas, String text, double x, double y, double px, Color color, {Color? shadow}) {
    if (shadow != null) {
      final o = px >= 6 ? 4.0 : 2.0;
      _fill(canvas, text, x + o, y + o, px, shadow);
    }
    _fill(canvas, text, x, y, px, color);
  }

  static void drawCentered(Canvas canvas, String text, double centreX, double y, double px, Color color,
      {Color? shadow}) {
    draw(canvas, text, centreX - widthOf(text, px) / 2, y, px, color, shadow: shadow);
  }

  static void _fill(Canvas canvas, String text, double x, double y, double px, Color color) {
    final path = Path();
    for (var i = 0; i < text.length; i++) {
      final bits = glyph(text[i]);
      if (bits == null) continue;
      final gx = x + i * 6 * px;
      for (var row = 0; row < 7; row++) {
        var col = 0;
        while (col < 5) {
          if (bits.codeUnitAt(row * 5 + col) != 0x23) {
            col++;
            continue;
          }
          final start = col;
          while (col < 5 && bits.codeUnitAt(row * 5 + col) == 0x23) {
            col++;
          }
          path.addRect(Rect.fromLTWH(gx + start * px, y + row * px, (col - start) * px, px));
        }
      }
    }
    _paint.color = color;
    canvas.drawPath(path, _paint);
  }
}
