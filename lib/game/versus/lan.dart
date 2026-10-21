import 'dart:async';
import 'dart:convert';

import 'lan_stub.dart' if (dart.library.io) 'lan_io.dart' as platform;

/// Playing with a friend on the same network. A host announces its game with a small UDP
/// broadcast every second; friends hear it (or type the host's address) and connect over
/// TCP. After that the two games swap small JSON messages, one per line.
abstract class Lan {
  /// Version of the messages: games only find and join games that speak the same one.
  static const protocol = 1;
  static const gamePort = 47821, beaconPort = 47820;

  /// False where there are no sockets (the browser): the game hides its 2 PLAYERS button.
  bool get supported;

  /// Starts hosting a game, announced with the host's [skin] so friends can tell whose it is.
  Future<LanHost> host(String skin);

  /// Games hosted on the network, each heard about once a second while listening.
  Stream<FoundGame> discover();

  /// Connects to the game hosted at [address].
  Future<LanLink> join(String address, {int port = gamePort});
}

/// The sockets of this device, or none in the browser.
Lan createLan() => platform.createLan();

/// A game this device is hosting, waiting for a friend.
abstract class LanHost {
  /// Friends connecting.
  Stream<LanLink> get joins;

  /// The port friends connect to: usually [Lan.gamePort].
  int get port;

  /// Where friends can reach this device, for typing in by hand: its IPv4 addresses, with
  /// the port when it isn't the usual one.
  Future<List<String>> addresses();

  /// Stops announcing the game and taking new friends. Links already made stay open.
  Future<void> close();
}

/// A game heard on the network.
class FoundGame {
  const FoundGame(this.address, this.port, this.skin);

  final String address;
  final int port;

  /// The host's skin id.
  final String skin;

  @override
  bool operator ==(Object other) => other is FoundGame && other.address == address && other.port == port;

  @override
  int get hashCode => Object.hash(address, port);
}

/// One end of a connection between two players.
abstract class LanLink {
  /// Messages from the other end. Done when the other end leaves or the connection drops.
  Stream<Map<String, Object?>> get messages;

  /// Sends [message] (JSON-encodable) to the other end. Does nothing once closed.
  void send(Map<String, Object?> message);

  Future<void> close();

  /// Two links joined to each other in memory.
  static (LanLink, LanLink) pair() {
    final a = StreamController<Map<String, Object?>>(), b = StreamController<Map<String, Object?>>();
    return (MemoryLink._(a, b), MemoryLink._(b, a));
  }
}

/// One end of a [LanLink.pair]. Messages go through JSON like on the network.
class MemoryLink implements LanLink {
  MemoryLink._(this._in, this._out);

  final StreamController<Map<String, Object?>> _in, _out;

  @override
  Stream<Map<String, Object?>> get messages => _in.stream;

  @override
  void send(Map<String, Object?> message) {
    if (_out.isClosed) return;
    _out.add((jsonDecode(jsonEncode(message)) as Map).cast<String, Object?>());
  }

  @override
  Future<void> close() async {
    _out.close(); // the other end hears that this one left
    _in.close();
  }
}

/// A pretend network in memory, for tests: games hosted on one [MemoryLan] can be found and
/// joined from another made with the same [MemoryNetwork].
class MemoryNetwork {
  final Map<String, _MemoryHost> _hosts = {};
  final StreamController<void> _changed = StreamController.broadcast();
  int _next = 1;

  Lan lan() => MemoryLan(this);
}

class MemoryLan implements Lan {
  MemoryLan(this.network);

  final MemoryNetwork network;

  @override
  bool get supported => true;

  @override
  Future<LanHost> host(String skin) async {
    final address = '10.0.0.${network._next++}';
    final host = _MemoryHost(network, address, skin);
    network._hosts[address] = host;
    network._changed.add(null);
    return host;
  }

  @override
  Stream<FoundGame> discover() {
    Iterable<FoundGame> all() => network._hosts.values.map((h) => FoundGame(h.address, Lan.gamePort, h.skin));
    late StreamController<FoundGame> out;
    StreamSubscription<void>? changes;
    out = StreamController(
      onListen: () {
        all().forEach(out.add);
        changes = network._changed.stream.listen((_) => all().forEach(out.add));
      },
      onCancel: () => changes?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<LanLink> join(String address, {int port = Lan.gamePort}) async {
    final host = network._hosts[address];
    if (host == null || port != Lan.gamePort) throw StateError('no game at $address');
    final (mine, theirs) = LanLink.pair();
    host._joins.add(theirs);
    return mine;
  }
}

class _MemoryHost implements LanHost {
  _MemoryHost(this.network, this.address, this.skin);

  final MemoryNetwork network;
  final String address, skin;
  final StreamController<LanLink> _joins = StreamController();

  @override
  Stream<LanLink> get joins => _joins.stream;

  @override
  int get port => Lan.gamePort;

  @override
  Future<List<String>> addresses() async => [address];

  @override
  Future<void> close() async {
    network._hosts.remove(address);
    _joins.close();
  }
}
