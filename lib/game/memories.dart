/// The little animated pictures memories come back with, one per memory.
enum MemoryScene {
  wings, oak, seven, rainbows,
  sunset, longShadows, door, hiding,
  constellation, sevenShadows, crying, moonCalls,
  runes, bargain, forgetting, brothers,
  eclipse, feeding, falling, name,
}

/// One memory of Pip, the winged bunny, coming back as the climb goes higher.
class Memory {
  const Memory(this.id, this.realm, this.scene, this.text, {this.arrival = false});

  /// Saved on the device, so never rename one.
  final String id;

  /// Index into `GameState.realms`: the realm where this memory is found.
  final int realm;

  /// The little animated picture shown with it (see `drawMemoryScene`).
  final MemoryScene scene;

  /// Upper case, in the pixel font's characters: A-Z 0-9 and ! ? & ' : . , - +
  final String text;

  /// Told the first time a run reaches [realm]. The others are fragments, drifting in the
  /// tunnel to be caught.
  final bool arrival;
}

/// The Last Burrow: the story the climb tells, one realm at a time. Each realm has a memory
/// that comes back on arrival, then three fragments to find there, always in this order.
abstract final class Memories {
  static const all = <Memory>[
    // Rainbow Sky
    Memory('sky-0', 0, MemoryScene.wings, "I WOKE UP FLYING. I DON'T REMEMBER WHERE I GOT THESE WINGS.", arrival: true),
    Memory('sky-1', 0, MemoryScene.oak, 'THERE WAS A BURROW UNDER THE OLD OAK. WARM, AND ALWAYS FULL OF NOISE.'),
    Memory('sky-2', 0, MemoryScene.seven, 'SEVEN OF US. I WAS THE SMALLEST. THEY CALLED ME PIP.'),
    Memory('sky-3', 0, MemoryScene.rainbows, "MAMA PAINTED RAINBOWS ON THE WALLS, SO WE WOULD NEVER FEAR THE DARK."),
    // Twilight
    Memory('twilight-0', 1, MemoryScene.sunset, "THE SKY IS TURNING. I'VE SEEN THIS SUNSET BEFORE. I KNOW I HAVE.", arrival: true),
    Memory('twilight-1', 1, MemoryScene.longShadows, 'ON THE LAST EVENING, PAPA SAID THE SHADOWS WERE GROWING LONGER THAN THEY SHOULD.'),
    Memory('twilight-2', 1, MemoryScene.door, 'WE SEALED THE DOOR. THE DARK CAME IN ANYWAY, SLOW, LIKE WATER.'),
    Memory('twilight-3', 1, MemoryScene.hiding, "I HID IN THE RAINBOW ROOM. I HEARD THEM CALLING MY NAME. I DIDN'T ANSWER."),
    // Starfall
    Memory('starfall-0', 2, MemoryScene.constellation, 'THE STARS ARE OUT. MAMA TAUGHT US THEIR NAMES. ONE OF THEM IS A BUNNY.', arrival: true),
    Memory('starfall-1', 2, MemoryScene.sevenShadows, 'WHEN I CAME OUT, THE BURROW WAS EMPTY. ONLY SEVEN SHADOWS ON THE WALL.'),
    Memory('starfall-2', 2, MemoryScene.crying, 'I CRIED TO THE MOON FOR THREE NIGHTS. ON THE THIRD NIGHT, IT ANSWERED.'),
    Memory('starfall-3', 2, MemoryScene.moonCalls, 'IT SAID: CLIMB TO ME, LITTLE ONE, AND I WILL GIVE BACK WHAT THE DARK TOOK.'),
    // Runelight
    Memory('runelight-0', 3, MemoryScene.runes, "THESE MARKS ON THE WALLS... THEY'RE MAMA'S RAINBOWS. THIS TUNNEL WAS OUR HOME.",
        arrival: true),
    Memory('runelight-1', 3, MemoryScene.bargain, 'THE MOON GAVE ME WINGS, BUT IT WANTED SOMETHING BACK. I SAID YES WITHOUT ASKING WHAT.'),
    Memory('runelight-2', 3, MemoryScene.forgetting, 'IT TOOK MY MEMORIES. THAT IS WHY I KEEP FORGETTING. THAT IS WHY I KEEP CLIMBING.'),
    Memory('runelight-3', 3, MemoryScene.brothers, "THE HOLLOW ONES WEAR MY BROTHERS' FACES. THEY DON'T WANT TO HURT ME. THEY WANT ME TO STAY."),
    // The Void
    Memory('void-0', 4, MemoryScene.eclipse, 'THE MOON IS GOING DARK. SOMETHING UP HERE IS EATING THE LIGHT.', arrival: true),
    Memory('void-1', 4, MemoryScene.feeding, 'THE MOON NEVER MEANT TO GIVE THEM BACK. IT FEEDS ON EVERYTHING WE LOSE.'),
    Memory('void-2', 4, MemoryScene.falling, 'EVERY TIME I FALL, IT TAKES ANOTHER MEMORY, AND I WAKE UP AT THE BOTTOM AGAIN.'),
    Memory('void-3', 4, MemoryScene.name, 'BUT I REMEMBER NOW. MY NAME IS PIP. AND I AM NOT DONE CLIMBING.'),
  ];

  static List<Memory> ofRealm(int realm) => all.where((m) => m.realm == realm).toList();
  static Memory arrivalOf(int realm) => all.firstWhere((m) => m.realm == realm && m.arrival);
  static List<Memory> fragmentsOf(int realm) => all.where((m) => m.realm == realm && !m.arrival).toList();
  static bool exists(String id) => all.any((m) => m.id == id);
}
