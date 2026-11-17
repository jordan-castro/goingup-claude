import 'game_state.dart';

/// The languages the game speaks, chosen with the EN / ES button on the home screen.
enum Lang { en, es }

/// Every word the game shows, in the player's language. All upper case, in the pixel font's
/// characters (which include Á É Í Ó Ú Ü Ñ ¿ ¡ for Spanish).
class Strings {
  const Strings._(this.lang);

  static const english = Strings._(Lang.en), spanish = Strings._(Lang.es);
  static Strings of(Lang lang) => lang == Lang.es ? spanish : english;

  final Lang lang;
  bool get _es => lang == Lang.es;
  String _(String en, String es) => _es ? es : en;

  // ---------- the run ----------

  String get meters => _('METERS', 'METROS');
  String get best => _('BEST', 'RÉCORD');
  String get holdToSteer => _('HOLD TO STEER', 'MANTÉN PARA DIRIGIR');
  String get entering => _('ENTERING', 'ENTRANDO A');
  String get lastCrash => _('LAST CRASH', 'ÚLTIMO CHOQUE');

  String toast(Toast toast, int value) => switch (toast) {
        Toast.shield => _('SHIELD!', '¡ESCUDO!'),
        Toast.shieldSaved => _('SHIELD SAVED YOU!', '¡EL ESCUDO TE SALVÓ!'),
        Toast.shieldBroken => _('THE SHIELD BROKE!', '¡SE ROMPIÓ EL ESCUDO!'),
        Toast.newBest => _('NEW BEST!', '¡NUEVO RÉCORD!'),
        Toast.secondChance => _('SECOND CHANCE!', '¡OTRA OPORTUNIDAD!'),
        Toast.milestone => _('$value METERS!', '¡$value METROS!'),
        Toast.theyFoundYou => _('THEY FOUND YOU.', 'TE ENCONTRARON.'),
        Toast.memory => _('A MEMORY RETURNED', 'VOLVIÓ UN RECUERDO'),
        Toast.turbo => _('TURBO!', '¡TURBO!'),
        Toast.tripleShield => _('TRIPLE SHIELD!', '¡ESCUDO TRIPLE!'),
      };

  // ---------- the title and game-over screens ----------

  List<String> howToPlay({required bool touch}) => touch
      ? _es
          ? const ['TOCA Y MANTÉN LA', 'PANTALLA PARA VOLAR.', 'EL CONEJO SIGUE TU', 'DEDO MIENTRAS TOCAS.']
          : const ['TOUCH AND HOLD THE', 'SCREEN TO FLY.', 'THE BUNNY FOLLOWS YOUR', 'FINGER WHILE YOU HOLD.']
      : _es
          ? const ['MANTÉN PULSADO EL BOTÓN', 'DEL RATÓN PARA VOLAR.', 'EL CONEJO SIGUE TU', 'CURSOR MIENTRAS PULSAS.']
          : const ['PRESS AND HOLD THE LEFT', 'MOUSE BUTTON TO FLY.', 'THE BUNNY FOLLOWS YOUR', 'CURSOR WHILE YOU HOLD.'];
  String get dontTouchTheWalls => _("DON'T TOUCH THE WALLS!", '¡NO TOQUES LAS PAREDES!');
  String start({required bool touch}) => touch ? _('TOUCH & HOLD', 'TOCA Y MANTÉN') : _('PRESS & HOLD', 'MANTÉN PULSADO');
  String get bonk => _('BONK!', '¡PUM!');
  String get gotYou => _('GOT YOU.', 'TE ATRAPÉ.');
  String get youFlew => _('YOU FLEW', 'VOLASTE');
  String get newBest => _('NEW BEST!', '¡NUEVO RÉCORD!');
  String get retry => _('HOLD TO RETRY', '¡OTRA VEZ!');
  String inRealm(int realm) => '${_('IN', 'EN')} ${realmName(realm)}';
  String coins(int n) => '$n ${n == 1 ? _('COIN', 'MONEDA') : _('COINS', 'MONEDAS')}';
  String get shop => _('SHOP', 'TIENDA');
  String get memories => _('MEMORIES', 'RECUERDOS');

  // ---------- racing a friend ----------

  String get twoPlayers => _('2 PLAYERS', '2 JUGADORES');
  String get getReady => _('GET READY!', '¡PREPÁRATE!');
  String wins(int wins, int losses) => '${_('WINS', 'VICTORIAS')} $wins - $losses';
  String get lastOneFlyingWins => _('THE LAST ONE FLYING WINS', 'GANA QUIEN SIGA VOLANDO');
  String get friend => _('FRIEND', 'AMIGO');
  String get you => _('YOU', 'TÚ');
  String get go => _('GO!', '¡YA!');
  String get youWin => _('YOU WIN!', '¡GANASTE!');
  String get youLose => _('YOU LOSE', 'PERDISTE');
  String get draw => _('DRAW!', '¡EMPATE!');
  String get friendLeft => _('YOUR FRIEND LEFT', 'TU AMIGO SE FUE');
  String get waitingForFriend => _('WAITING FOR YOUR FRIEND', 'ESPERANDO A TU AMIGO');
  String get friendCrashed => _('YOUR FRIEND CRASHED', 'TU AMIGO CHOCÓ');
  String get bothCrashed => _('YOU BOTH CRASHED AT ONCE', 'CHOCARON A LA VEZ');
  String get friendKeptFlying => _('YOUR FRIEND KEPT FLYING', 'TU AMIGO SIGUIÓ VOLANDO');
  String get rematch => _('REMATCH', 'REVANCHA');
  String get friendWantsRematch => _('YOUR FRIEND WANTS A REMATCH!', '¡TU AMIGO QUIERE LA REVANCHA!');
  String get leave => _('LEAVE', 'SALIR');
  String get hostAGame => _('HOST A GAME', 'CREAR PARTIDA');
  String get joinAGame => _('JOIN A GAME', 'UNIRSE A PARTIDA');
  String get typeAnAddress => _('TYPE AN ADDRESS', 'ESCRIBIR DIRECCIÓN');
  String get join => _('JOIN', 'UNIRSE');
  String get cancel => _('CANCEL', 'CANCELAR');
  String get startRace => _('START', 'EMPEZAR');
  String get ok => 'OK';
  String get hosting => _('HOSTING', 'ANFITRIÓN');
  String get waitingForAFriend => _('WAITING FOR A FRIEND', 'ESPERANDO A UN AMIGO');
  String get lookingForGames => _('LOOKING FOR GAMES', 'BUSCANDO PARTIDAS');
  String get joining => _('JOINING', 'UNIÉNDOSE');
  String get sayingHello => _('SAYING HELLO...', 'SALUDANDO...');
  String gameOf(String bunny) => _("$bunny'S GAME", 'PARTIDA DE $bunny');
  List<String> get versusHow => _es
      ? const ['VUELA EL MISMO TÚNEL QUE', 'UN AMIGO EN EL MISMO WI-FI.', 'NO PUEDEN CHOCAR ENTRE SÍ:',
          'TU AMIGO ES UN FANTASMA.', '¡GANA QUIEN SIGA VOLANDO!']
      : const ['FLY THE SAME TUNNEL AS A', 'FRIEND ON THE SAME WI-FI.', "YOU CAN'T BUMP INTO EACH",
          "OTHER: THEY'RE A GHOST.", 'THE LAST ONE FLYING WINS!'];
  List<String> get howToJoin => _es
      ? const ['EN EL MISMO WI-FI, TU AMIGO', 'PULSA 2 JUGADORES Y LUEGO', 'UNIRSE A PARTIDA. O PUEDE', 'ESCRIBIR:']
      : const ['ON THE SAME WI-FI, THEY', 'PRESS 2 PLAYERS, THEN', 'JOIN A GAME. OR THEY CAN', 'TYPE IN:'];
  List<String> get howToHost => _es
      ? const ['EL ANFITRIÓN PULSA', 'CREAR PARTIDA EN EL', 'MISMO WI-FI.']
      : const ['THE HOST PRESSES', 'HOST A GAME ON THE', 'SAME WI-FI.'];
  List<String> get cantListen => _es
      ? const ['AQUÍ NO SE OYEN PARTIDAS:', 'ESCRIBE LA DIRECCIÓN.']
      : const ["CAN'T LISTEN FOR GAMES HERE:", 'TYPE THE ADDRESS INSTEAD.'];
  List<String> get waitingForHost => _es
      ? const ['ESPERANDO QUE EL ANFITRIÓN', 'EMPIECE LA CARRERA']
      : const ['WAITING FOR THE HOST', 'TO START THE RACE'];
  List<String> get couldNotHost => _es
      ? const ['NO SE PUDO CREAR LA PARTIDA.', '¿ESTÁ ENCENDIDO EL WI-FI?']
      : const ['COULD NOT HOST A GAME.', 'IS THE WI-FI ON?'];
  String get couldNotJoin => _('COULD NOT JOIN', 'NO SE PUDO UNIR A');
  String get yourFriendLeft => _('YOUR FRIEND LEFT.', 'TU AMIGO SE FUE.');

  // ---------- the realms ----------

  String realmName(int realm) => _es
      ? const ['CIELO ARCOÍRIS', 'CREPÚSCULO', 'CENIZA', 'EL HUECO', 'EL VACÍO'][realm]
      : GameState.realms[realm].name;

  // ---------- the shop ----------

  String shelf(Shelf shelf) => switch (shelf) {
        Shelf.bunnies => _('BUNNIES', 'CONEJOS'),
        Shelf.trails => _('TRAILS', 'ESTELAS'),
        Shelf.powers => _('POWER-UPS', 'PODERES'),
      };
  String kind(Shelf shelf) => switch (shelf) {
        Shelf.bunnies => _('BUNNY', 'CONEJO'),
        Shelf.trails => _('TRAIL', 'ESTELA'),
        Shelf.powers => _('POWER-UP', 'PODER'),
      };
  String get yay => _('YAY!', '¡BIEN!');
  String get wearing => _('WEARING', 'PUESTO');
  String get owned => _('OWNED', 'TUYO');
  String get wearIt => _('WEAR IT', 'PONÉRTELO');
  String get buy => _('BUY', 'COMPRAR');
  String needMore(int coins) => _('NEED $coins MORE COINS', 'TE FALTAN $coins MONEDAS');
  String have(int count) => _('HAVE $count', 'TIENES $count');
  String get back => _('BACK', 'VOLVER');

  String itemName(ShopItem item) => !_es
      ? item.name
      : const {
            'snowball': 'COPO',
            'berry': 'FRESA',
            'cocoa': 'CACAO',
            'mint': 'MENTA',
            'midnight': 'NOCHE',
            'golden': 'DORADO',
            'rainbow': 'ARCOÍRIS',
            'candy': 'DULCE',
            'ocean': 'OCÉANO',
            'fire': 'FUEGO',
            'aurora': 'AURORA',
            'gold': 'ORO',
            'peach': 'DURAZNO',
            'storm': 'TORMENTA',
            'lilac': 'LILA',
            'ember': 'BRASA',
            'comet': 'COMETA',
            'guardian': 'GUARDIÁN',
            'phantom': 'FANTASMA',
            'sunset': 'OCASO',
            'lavender': 'LAVANDA',
            'mono': 'MONOCROMO',
            'neon': 'NEÓN',
            'magnet': 'IMÁN',
            'lucky': 'SUERTE',
            'phoenix': 'FÉNIX',
            'turbo': 'TURBO',
            'triple-shield': 'ESCUDO X3',
          }[item.id] ??
          item.name;

  /// What a perk does, short enough for the shop's preview.
  String perk(Perk perk) => !_es
      ? perk.description
      : switch (perk) {
          Perk.none => '',
          Perk.headStart => 'EMPIEZA 50% MÁS RÁPIDO',
          Perk.startShield => 'EMPIEZA CON ESCUDO',
          Perk.hollowProof => 'LOS HUECOS LO ATRAVIESAN',
          Perk.magnet => 'ATRAE LAS MONEDAS',
          Perk.doubleCoins => 'CADA MONEDA VALE DOBLE',
          Perk.secondChance => 'PERDONA UN CHOQUE',
        };

  /// What a power-up does, a few short lines for the shop's preview.
  List<String> powerUpHelp(Boost boost) => switch (boost) {
        Boost.turbo => _es
            ? const ['¿MUY LENTO?', 'TÓCALO EN EL VUELO', 'Y VAS MÁS RÁPIDO.']
            : const ['TOO SLOW?', 'TAP IT WHILE YOU FLY', 'TO GO MUCH FASTER.'],
        Boost.tripleShield => _es
            ? const ['UN ESCUDO QUE', 'AGUANTA 3 GOLPES', 'ANTES DE ROMPERSE.']
            : const ['A SHIELD THAT', 'TAKES 3 HITS', 'BEFORE IT BREAKS.'],
      };

  // ---------- memories ----------

  String memoriesCount(int found, int all) => _('$found OF $all', '$found DE $all');
  String get isNew => _('NEW', 'NUEVO');
  String get reachToRemember => _('REACH THIS REALM TO REMEMBER', 'LLEGA A ESTE REINO PARA RECORDAR');
  String get forgotten => _('- FORGOTTEN -', '- OLVIDADO -');
  String get tapToSee => _('TAP A MEMORY TO SEE IT AGAIN', 'TOCA UN RECUERDO PARA VERLO');
  String get remembered => _('REMEMBERED', 'RECORDADO');
  String toContinue({required bool touch}) =>
      touch ? _('TAP TO CONTINUE', 'TOCA PARA SEGUIR') : _('CLICK TO CONTINUE', 'HAZ CLIC PARA SEGUIR');

  /// The words of [memory] in this language.
  String memory(Memory memory) => _es ? (_memoriesEs[memory.id] ?? memory.text) : memory.text;

  static const _memoriesEs = {
    'sky-0': 'DESPERTÉ VOLANDO. NO RECUERDO DE DÓNDE SALIERON ESTAS ALAS.',
    'sky-1': 'HABÍA UNA MADRIGUERA BAJO EL VIEJO ROBLE. CÁLIDA, Y SIEMPRE LLENA DE RUIDO.',
    'sky-2': 'ÉRAMOS SIETE. YO ERA EL MÁS PEQUEÑO. ME LLAMABAN PIP.',
    'sky-3': 'MAMÁ PINTABA ARCOÍRIS EN LAS PAREDES PARA QUE NUNCA TEMIÉRAMOS A LA OSCURIDAD.',
    'twilight-0': 'EL CIELO ESTÁ CAMBIANDO. YA HE VISTO ESTE ATARDECER. LO SÉ.',
    'twilight-1': 'LA ÚLTIMA TARDE, PAPÁ DIJO QUE LAS SOMBRAS CRECÍAN MÁS DE LO NORMAL.',
    'twilight-2': 'SELLAMOS LA PUERTA. LA OSCURIDAD ENTRÓ IGUAL, LENTA, COMO EL AGUA.',
    'twilight-3': 'ME ESCONDÍ EN EL CUARTO DEL ARCOÍRIS. OÍ QUE ME LLAMABAN. NO RESPONDÍ.',
    'starfall-0': 'SALIERON LAS ESTRELLAS. MAMÁ NOS ENSEÑÓ SUS NOMBRES. UNA ES UN CONEJO.',
    'starfall-1': 'CUANDO SALÍ, LA MADRIGUERA ESTABA VACÍA. SOLO SIETE SOMBRAS EN LA PARED.',
    'starfall-2': 'LE LLORÉ A LA LUNA TRES NOCHES. LA TERCERA NOCHE, ME RESPONDIÓ.',
    'starfall-3': 'DIJO: SUBE HASTA MÍ, PEQUEÑO, Y TE DEVOLVERÉ LO QUE LA OSCURIDAD SE LLEVÓ.',
    'runelight-0': 'ESTAS MARCAS... SON LOS ARCOÍRIS DE MAMÁ. ESTE TÚNEL ERA NUESTRO HOGAR.',
    'runelight-1': 'LA LUNA ME DIO ALAS, PERO PIDIÓ ALGO A CAMBIO. DIJE QUE SÍ SIN PREGUNTAR QUÉ.',
    'runelight-2': 'SE LLEVÓ MIS RECUERDOS. POR ESO SIGO OLVIDANDO. POR ESO SIGO SUBIENDO.',
    'runelight-3': 'LOS HUECOS TIENEN LAS CARAS DE MIS HERMANOS. NO QUIEREN DAÑARME. QUIEREN QUE ME QUEDE.',
    'void-0': 'LA LUNA SE APAGA. ALGO AQUÍ ARRIBA SE ESTÁ COMIENDO LA LUZ.',
    'void-1': 'LA LUNA NUNCA PENSÓ DEVOLVERLOS. SE ALIMENTA DE TODO LO QUE PERDEMOS.',
    'void-2': 'CADA VEZ QUE CAIGO, SE LLEVA OTRO RECUERDO, Y DESPIERTO ABAJO OTRA VEZ.',
    'void-3': 'PERO AHORA LO RECUERDO. ME LLAMO PIP. Y NO HE TERMINADO DE SUBIR.',
  };
}
