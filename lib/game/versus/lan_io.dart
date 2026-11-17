import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lan.dart';

Lan createLan() => _IoLan();

class _IoLan implements Lan {
  @override
  bool get supported => true;

  @override
  Future<LanHost> host(String skin) async {
    ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, Lan.gamePort);
    } on SocketException {
      // the usual port is taken (another copy of the game on this device): any port will do,
      // the announcement says which
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    try {
      final beacon = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      beacon.broadcastEnabled = true;
      return _IoHost(server, beacon, skin);
    } catch (_) {
      await server.close();
      rethrow;
    }
  }

  @override
  Stream<FoundGame> discover() {
    late StreamController<FoundGame> out;
    RawDatagramSocket? socket;
    out = StreamController(
      onListen: () async {
        try {
          final s = socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, Lan.beaconPort, reuseAddress: true);
          s.listen((event) {
            if (event != RawSocketEvent.read) return;
            final datagram = s.receive();
            if (datagram == null) return;
            try {
              final m = jsonDecode(utf8.decode(datagram.data));
              if (m is Map && m['goingup'] == Lan.protocol && m['port'] is int) {
                out.add(FoundGame(datagram.address.address, m['port'] as int, '${m['skin'] ?? ''}'));
              }
            } catch (_) {
              // not one of ours
            }
          });
        } catch (e) {
          out.addError(e); // can't listen (the port is taken): games can still be typed in
        }
      },
      onCancel: () => socket?.close(),
    );
    return out.stream;
  }

  @override
  Future<LanLink> join(String address, {int port = Lan.gamePort}) async {
    final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 4));
    return _IoLink(socket);
  }
}

class _IoHost implements LanHost {
  _IoHost(this._server, this._beacon, String skin) {
    final announcement = utf8.encode(jsonEncode({'goingup': Lan.protocol, 'port': _server.port, 'skin': skin}));
    Future<void> announce() async {
      // the whole network, and each of this device's own networks (some systems only send
      // the first to one of them)
      final targets = {InternetAddress('255.255.255.255')};
      for (final address in await _ownAddresses()) {
        final parts = address.split('.');
        targets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
      }
      for (final target in targets) {
        try {
          _beacon.send(announcement, target, Lan.beaconPort);
        } catch (_) {
          // that network can't be reached
        }
      }
    }

    announce();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => announce());
  }

  final ServerSocket _server;
  final RawDatagramSocket _beacon;
  late final Timer _timer;

  @override
  Stream<LanLink> get joins => _server.map(_IoLink.new);

  @override
  int get port => _server.port;

  @override
  Future<List<String>> addresses() async {
    final suffix = port == Lan.gamePort ? '' : ':$port';
    return [for (final address in await _ownAddresses()) '$address$suffix'];
  }

  @override
  Future<void> close() async {
    _timer.cancel();
    _beacon.close();
    await _server.close();
  }
}

Future<List<String>> _ownAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal) a.address,
    ];
  } catch (_) {
    return const [];
  }
}

class _IoLink implements LanLink {
  _IoLink(this._socket) {
    _socket.setOption(SocketOption.tcpNoDelay, true); // small messages, sent straight away
    _socket.done.catchError((Object _) {}); // a dropped connection ends [messages] instead
  }

  final Socket _socket;
  bool _closed = false;

  @override
  late final Stream<Map<String, Object?>> messages = utf8.decoder
      .bind(_socket)
      .transform(const LineSplitter())
      .map((line) {
        try {
          final m = jsonDecode(line);
          return m is Map<String, Object?> ? m : null;
        } catch (_) {
          return null;
        }
      })
      .where((m) => m != null)
      .cast<Map<String, Object?>>();

  @override
  void send(Map<String, Object?> message) {
    if (_closed) return;
    try {
      _socket.write('${jsonEncode(message)}\n');
    } catch (_) {
      _closed = true; // the connection is gone; [messages] will end
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _socket.flush().timeout(const Duration(seconds: 1)); // the goodbye goes out first
    } catch (_) {
      // gone already
    }
    _socket.destroy();
  }
}
