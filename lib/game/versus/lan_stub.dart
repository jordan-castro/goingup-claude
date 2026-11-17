import 'lan.dart';

/// No sockets here (the browser): two-player games aren't offered.
Lan createLan() => _NoLan();

class _NoLan implements Lan {
  @override
  bool get supported => false;

  @override
  Future<LanHost> host(String skin) => Future.error(UnsupportedError('no local network here'));

  @override
  Stream<FoundGame> discover() => const Stream.empty();

  @override
  Future<LanLink> join(String address, {int port = Lan.gamePort}) =>
      Future.error(UnsupportedError('no local network here'));
}
