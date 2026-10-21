import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show KeyEvent, LogicalKeyboardKey;

import '../drawing.dart';
import '../game_state.dart';
import '../going_up_game.dart';
import '../palette.dart';
import '../pixel_font.dart';
import '../sprites.dart';
import '../versus/lan.dart';
import '../versus/match.dart';

enum VersusPage {
  /// What a two-player game is, and HOST or JOIN.
  menu,

  /// Announcing a game, waiting for a friend to join.
  hosting,

  /// Listening for games on the network.
  finding,

  /// Typing in a host's address.
  typing,

  /// Joining a game.
  connecting,

  /// Both here: the host starts the race.
  lobby,

  /// Something went wrong, or the friend left.
  message,
}

/// The two-player screens, opened with the 2 PLAYERS button on the title: host a game or
/// join one on the same network, then wait together until the host starts the race. Drawn in
/// field coordinates over everything but the speaker button. Closes itself when the race's
/// countdown begins.
class VersusScreen extends Component with HasGameReference<GoingUpGame> {
  static const double _w = GameState.width;

  bool isOpen = false;
  VersusPage page = VersusPage.menu;

  /// This device's addresses while hosting, the games heard while finding (with when each
  /// was last heard), and the address being typed or joined.
  List<String> addresses = const [];
  final Map<FoundGame, double> _found = {};
  bool _cantListen = false;
  String typed = '';
  String _joining = '';
  List<String> _message = const [];

  LanHost? _host;
  StreamSubscription<LanLink>? _joins;
  StreamSubscription<FoundGame>? _discovery;
  int _attempt = 0; // bumped on leaving a page, so a late answer from the network is ignored
  double _time = 0;
  final _pixels = Paint()..filterQuality = FilterQuality.none;
  final _faded = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.5);

  /// Games heard in the last few seconds, at most four.
  List<FoundGame> get found => _found.keys.take(4).toList();

  void open() {
    isOpen = true;
    page = VersusPage.menu;
  }

  void close() {
    _stop();
    isOpen = false;
  }

  /// Stops hosting and listening.
  void _stop() {
    _attempt++;
    _joins?.cancel();
    _joins = null;
    _host?.close();
    _host = null;
    _discovery?.cancel();
    _discovery = null;
    _found.clear();
  }

  // ---------- actions ----------

  Future<void> host() async {
    _stop();
    page = VersusPage.hosting;
    addresses = const [];
    final attempt = _attempt;
    try {
      final host = await game.lan.host(game.state.skinId);
      if (attempt != _attempt) {
        host.close();
        return;
      }
      _host = host;
      _joins = host.joins.listen((link) {
        if (attempt != _attempt || game.match != null) {
          link.close(); // one friend at a time
          return;
        }
        _stop(); // stop announcing the game
        _startMatch(link, hosting: true);
      });
      final list = await host.addresses();
      if (attempt == _attempt) addresses = list;
    } catch (_) {
      if (attempt == _attempt) _say(const ['COULD NOT HOST A GAME.', 'IS THE WI-FI ON?']);
    }
  }

  void find() {
    _stop();
    page = VersusPage.finding;
    _cantListen = false;
    _discovery = game.lan.discover().listen((g) => _found[g] = _time, onError: (Object _) => _cantListen = true);
  }

  Future<void> join(String address, {int port = Lan.gamePort}) async {
    _stop();
    page = VersusPage.connecting;
    _joining = address;
    final attempt = _attempt;
    try {
      final link = await game.lan.join(address, port: port);
      if (attempt != _attempt) {
        link.close();
        return;
      }
      _startMatch(link, hosting: false);
    } catch (_) {
      if (attempt == _attempt) _say(['COULD NOT JOIN', address]);
    }
  }

  void _startMatch(LanLink link, {required bool hosting}) {
    game.match = VersusMatch(link, game.state, hosting: hosting);
    page = VersusPage.lobby;
  }

  void _say(List<String> lines) {
    _stop();
    _message = lines;
    page = VersusPage.message;
  }

  /// Back one step: the BACK, CANCEL and LEAVE buttons, and Escape.
  void back() {
    switch (page) {
      case VersusPage.menu:
        close();
      case VersusPage.hosting || VersusPage.finding || VersusPage.message:
        _stop();
        page = VersusPage.menu;
      case VersusPage.typing || VersusPage.connecting:
        find();
      case VersusPage.lobby:
        game.leaveMatch();
        page = VersusPage.menu;
    }
  }

  void _typeKey(String key) {
    if (key == 'DEL') {
      if (typed.isNotEmpty) typed = typed.substring(0, typed.length - 1);
    } else if (typed.length < 21) {
      typed += key;
    }
  }

  /// Four numbers with dots between, and maybe a port after a colon (typed on a keyboard: only
  /// needed when two copies of the game share a computer).
  bool get _addressLooksRight => RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?$').hasMatch(typed);

  void _joinTyped() {
    if (!_addressLooksRight) return;
    final parts = typed.split(':');
    join(parts[0], port: parts.length > 1 ? int.parse(parts[1]) : Lan.gamePort);
  }

  /// A key pressed on a keyboard while open: typing an address, Enter to join, Escape to go
  /// back. Returns whether it was used.
  bool keyPressed(KeyEvent event) {
    final key = event.logicalKey, character = event.character ?? '';
    if (key == LogicalKeyboardKey.escape) {
      back();
      return true;
    }
    if (page != VersusPage.typing) return false;
    if (RegExp(r'^[0-9.:]$').hasMatch(character)) {
      _typeKey(character);
    } else if (key == LogicalKeyboardKey.backspace) {
      _typeKey('DEL');
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _joinTyped();
    } else {
      return false;
    }
    return true;
  }

  @override
  void update(double dt) {
    _time += dt;
    _found.removeWhere((_, heard) => _time - heard > 4);
    final match = game.match;
    if (match != null && match.phase == MatchPhase.closed) {
      game.match = null;
      if (match.friendLeft) {
        game.state.toTitle();
        isOpen = true;
        _say(const ['YOUR FRIEND LEFT.']);
      }
    } else if (isOpen && page == VersusPage.lobby) {
      if (match == null) {
        page = VersusPage.menu;
      } else if (match.phase == MatchPhase.countdown) {
        isOpen = false; // the race begins
      }
    }
  }

  @override
  void onRemove() {
    _stop();
    super.onRemove();
  }

  // ---------- layout (field units) ----------

  /// Top of the screens, which are 470 tall: centred when the screen has room to spare.
  double get _top {
    final top = 10 + game.safeTop;
    final spare = (game.state.height - game.safeBottom - 60) - (top + 470);
    return top + math.max(0.0, spare / 2);
  }

  Rect get _backButton => Rect.fromLTWH((_w - 160) / 2, _top + 430, 160, 40);
  Rect _wide(double y, [double h = 52]) => Rect.fromLTWH(16, _top + y, _w - 32, h);
  Rect _key(int i) => Rect.fromLTWH(16 + (i % 3) * 124, _top + 120 + (i ~/ 3) * 58, 120, 50);
  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'DEL'];

  /// The buttons on the page showing: where, what they say (empty for a game found on the
  /// network, which draws itself), and what they do.
  List<VersusButton> get buttons {
    final match = game.match;
    return switch (page) {
      VersusPage.menu => [
          VersusButton(_wide(236), 'HOST A GAME', host, primary: true),
          VersusButton(_wide(300), 'JOIN A GAME', find, primary: true),
          VersusButton(_backButton, 'BACK', back),
        ],
      VersusPage.hosting => [VersusButton(_backButton, 'CANCEL', back)],
      VersusPage.finding => [
          for (final (i, g) in found.indexed)
            VersusButton(_wide(64 + i * 62.0, 54), '', () => join(g.address, port: g.port), game: g),
          VersusButton(_wide(330, 46), 'TYPE AN ADDRESS', () {
            _stop();
            page = VersusPage.typing;
          }),
          VersusButton(_backButton, 'BACK', back),
        ],
      VersusPage.typing => [
          for (final (i, k) in _keys.indexed) VersusButton(_key(i), k, () => _typeKey(k)),
          VersusButton(_wide(360, 50), 'JOIN', _joinTyped, primary: _addressLooksRight),
          VersusButton(_backButton, 'BACK', back),
        ],
      VersusPage.connecting => [VersusButton(_backButton, 'CANCEL', back)],
      VersusPage.lobby => [
          if (match != null && match.hosting && match.friendHere && !match.ready)
            VersusButton(_wide(320), 'START', match.setReady, primary: true),
          VersusButton(_backButton, 'LEAVE', back),
        ],
      VersusPage.message => [VersusButton(_wide(300), 'OK', back, primary: true)],
    };
  }

  // ---------- input ----------

  /// A press at [p] (field units) while open.
  void press(Offset p) {
    for (final button in buttons) {
      if (button.rect.inflate(3).contains(p)) {
        button.onPress();
        game.sfx.play(const SoundCue(Sfx.click));
        return;
      }
    }
  }

  // ---------- drawing ----------

  @override
  void render(Canvas canvas) {
    if (!isOpen) return;
    final state = game.state;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, state.height), Paint()..color = Palette.page.withValues(alpha: 0.92));
    final top = _top;
    final heading = switch (page) {
      VersusPage.hosting => 'HOSTING',
      VersusPage.finding || VersusPage.connecting => 'JOIN A GAME',
      VersusPage.typing => 'TYPE AN ADDRESS',
      _ => '2 PLAYERS',
    };
    PixelFont.drawCentered(canvas, heading, _w / 2, top + 2, heading.length > 12 ? 3 : 5, Palette.text,
        shadow: Palette.hot);

    switch (page) {
      case VersusPage.menu:
        drawPanel(canvas, _wide(56, 140));
        _lines(canvas, const [
          'FLY THE SAME TUNNEL AS A',
          'FRIEND ON THE SAME WI-FI.',
          "YOU CAN'T BUMP INTO EACH",
          "OTHER: THEY'RE A GHOST.",
          'THE LAST ONE FLYING WINS!',
        ], top + 72, last: Palette.sun);
      case VersusPage.hosting:
        PixelFont.drawCentered(canvas, 'WAITING FOR A FRIEND${_dots()}', _w / 2, top + 64, 2, Palette.sun);
        drawPanel(canvas, _wide(96, 104));
        _lines(canvas, const ['ON THE SAME WI-FI, THEY', 'PRESS 2 PLAYERS, THEN', 'JOIN A GAME. OR THEY CAN', 'TYPE IN:'],
            top + 108);
        var y = top + 220;
        for (final address in addresses.take(4)) {
          PixelFont.drawCentered(canvas, address, _w / 2, y, 3, Palette.text, shadow: Palette.ink);
          y += 34;
        }
        if (addresses.isEmpty) PixelFont.drawCentered(canvas, '...', _w / 2, y, 3, Palette.muted);
      case VersusPage.finding:
        if (found.isEmpty) {
          PixelFont.drawCentered(canvas, 'LOOKING FOR GAMES${_dots()}', _w / 2, top + 90, 2, Palette.sun);
          _lines(canvas, const ['THE HOST PRESSES', 'HOST A GAME ON THE', 'SAME WI-FI.'], top + 130);
        }
        if (_cantListen) _lines(canvas, const ["CAN'T LISTEN FOR GAMES HERE:", 'TYPE THE ADDRESS INSTEAD.'], top + 250);
      case VersusPage.typing:
        final field = _wide(56, 52);
        drawPanel(canvas, field, edge: Palette.sun);
        final cursor = blinkOn(_time) ? '-' : ' ';
        PixelFont.drawCentered(canvas, '$typed$cursor', _w / 2, field.top + 15, 3, Palette.text);
      case VersusPage.connecting:
        PixelFont.drawCentered(canvas, 'JOINING${_dots()}', _w / 2, top + 120, 3, Palette.sun);
        PixelFont.drawCentered(canvas, _joining, _w / 2, top + 170, 2, Palette.muted);
      case VersusPage.lobby:
        _lobby(canvas, top);
      case VersusPage.message:
        _lines(canvas, _message, top + 140, color: Palette.text);
    }

    for (final button in buttons) {
      _drawButton(canvas, button);
    }
  }

  void _lobby(Canvas canvas, double top) {
    final match = game.match;
    if (match == null) return;
    final mine = Rect.fromLTWH(16, top + 60, 176, 190), theirs = Rect.fromLTWH(208, top + 60, 176, 190);
    for (final (rect, label, skin, here, ghost) in [
      (mine, 'YOU', game.state.skin, true, false),
      (theirs, 'FRIEND', Shop.skin(match.friendSkin ?? ''), match.friendHere, true),
    ]) {
      drawPanel(canvas, rect);
      PixelFont.drawCentered(canvas, label, rect.center.dx, rect.top + 12, 2, Palette.muted);
      if (!here) {
        PixelFont.drawCentered(canvas, '...', rect.center.dx, rect.center.dy, 3, Palette.muted);
        continue;
      }
      final anchor = Offset(rect.center.dx, rect.top + 92 + math.sin(_time * 3 + rect.left) * 4);
      if (ghost) canvas.saveLayer(rect, _faded); // the friend shows as a ghost, as in the race
      _bunny(canvas, game.sprites.skin(skin), anchor, 3, wingsUp: (_time * 5 + rect.left).floor().isEven);
      if (ghost) canvas.restore();
      PixelFont.drawCentered(canvas, skin.name, rect.center.dx, rect.bottom - 30, 2, Palette.text);
    }
    final List<String> status = match.hosting
        ? (match.friendHere ? (match.ready ? const ['GET READY!'] : const []) : const ['SAYING HELLO...'])
        : const ['WAITING FOR THE HOST', 'TO START THE RACE'];
    _lines(canvas, status, top + 276, color: Palette.sun);
  }

  /// Centred lines of small text, 22 apart; the [last] colour, if given, for the last line.
  void _lines(Canvas canvas, List<String> lines, double y, {Color color = Palette.muted, Color? last}) {
    for (var i = 0; i < lines.length; i++) {
      PixelFont.drawCentered(canvas, lines[i], _w / 2, y + i * 22, 2, i == lines.length - 1 ? last ?? color : color);
    }
  }

  String _dots() => '.' * ((_time * 2).floor() % 4);

  void _drawButton(Canvas canvas, VersusButton button) {
    final rect = button.rect;
    drawPanel(canvas, rect, edge: button.primary ? Palette.sun : Palette.panelEdge);
    if (button.label.isNotEmpty) {
      final px = rect.height >= 50 && PixelFont.widthOf(button.label, 3) < rect.width - 16 ? 3.0 : 2.0;
      PixelFont.drawCentered(canvas, button.label, rect.center.dx, rect.center.dy - 3.5 * px, px,
          button.primary ? Palette.sun : Palette.text);
      return;
    }
    // a game found on the network: the host's bunny, whose game it is, and where
    final g = button.game;
    if (g == null) return;
    final skin = Shop.skin(g.skin);
    _bunny(canvas, game.sprites.skin(skin), Offset(rect.left + 34, rect.top + 26), 1.4, wingsUp: false);
    PixelFont.draw(canvas, "${skin.name}'S GAME", rect.left + 70, rect.top + 11, 2, Palette.text);
    PixelFont.draw(canvas, g.address, rect.left + 70, rect.top + 31, 2, Palette.muted);
  }

  /// The bunny's sprite at scale [s], placed by its anchor (sprite column 8, row 14).
  void _bunny(Canvas canvas, BunnySprites sprites, Offset anchor, double s, {required bool wingsUp}) {
    void image(Image image, double x, double y) {
      final w = image.width.toDouble(), h = image.height.toDouble();
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, w, h),
          Rect.fromLTWH(anchor.dx + x * s, anchor.dy + y * s, w * s, h * s), _pixels);
    }

    image(wingsUp ? sprites.wingUpLeft : sprites.wingDownLeft, -14, -1);
    image(wingsUp ? sprites.wingUpRight : sprites.wingDownRight, 7, -1);
    image(sprites.bunny, -8, -14);
  }
}

/// A button on the two-player screens.
class VersusButton {
  const VersusButton(this.rect, this.label, this.onPress, {this.primary = false, this.game});

  final Rect rect;
  final String label;
  final void Function() onPress;
  final bool primary;

  /// For a game found on the network, which one.
  final FoundGame? game;
}
