# goingUP

A winged pixel bunny flies up an endless rainbow tunnel. Press and hold (or touch and hold) and the
bunny follows your pointer; let go and it stays put. Touch a wall and the run ends. The tunnel
speeds up the longer you survive, and the top-right counter shows how many screens you have flown
past. After a crash, the next run shows a "LAST CRASH" ghost where you went down. Late in a run,
the Hollow Ones come hopping, and the coins you collect buy new bunnies and trails in the shop.

The higher you climb, the darker, stranger and more broken the world becomes, and the more the
bunny remembers of who it is and how it got here.

Built with Flutter and the [Flame](https://flame-engine.org) game engine. Package / bundle ID:
`us.epochtech.goingup`. Runs on Android, iOS, the web, Windows, macOS and Linux.

## Coins, wide spots and the shield

- **Bonus zones:** every 10 screens the tunnel opens wide for a few seconds, with a snake of coins
  and a shield.
- **Wide spots:** ordinary tunnel also opens up at random now and then, at any speed, with a short
  line of coins.
- **Shields** (purple badges, now and then in the tunnel) are the only power-up. A shield absorbs
  one hit, from a wall or a Hollow One. The level then runs at half speed for 2 s and catches back
  up in 0.5 s. The shield stays until it's used.

## The coin shop

The **SHOP** button (bottom-right on the title and game-over screens) opens the coin shop. When
there's something new you can afford, the button turns gold and a pink dot blinks.

| Shelf | Free | 100 | 250 | 500 | 1000 | 2000 |
| --- | --- | --- | --- | --- | --- | --- |
| Bunnies | Snowball | Berry (leafy wings) | Cocoa | Mint | Midnight (glowing eyes) | Golden |
| Trails | Rainbow | Candy | Ocean | Fire | Aurora | Gold |

- Pick an item to see it on the big preview, then press **BUY**. A new item goes straight on.
- Switching between items you own is free.
- The crash burst takes the colours of your trail.
- Escape (or **BACK**) closes the shop.

Items live in `lib/game/shop.dart`. Each item has an `id` that is saved on the device, so never
rename one.

## The Hollow Ones

From screen 25, the Hollow Ones come for Pip: what's left of its family, turned into ragged
copies of Pip itself, its own pixel body gone dark: ash-grey with a blood-red outline, a torn ear, one glowing red eye, a sewn-on button for the other and a
stitched grin full of teeth. They don't drift, they hop: each waits at a spot, twitching, then
crouches (its eye flares, its grin widens) and leaps to the next. By screen 45, when the run is
fully dark, they are as common as they get. The first one in each run comes with a warning:
"THEY FOUND YOU."

- Touch one and the run ends with "GOT YOU." instead of "BONK!".
- A shield tears one apart instead.
- They only appear where the tunnel is wide enough that, wherever one hops, one side always has
  56 units free for the bunny. Sometimes one guards the coins in a wide spot.
- Only the body can catch the bunny; the ears and the leap are just for show.

All of these numbers live in `lib/game/tuning.dart` (`GameTuning`). You can also set the bonus zone
interval for one build without editing code:

```bash
flutter run -d chrome --dart-define=BONUS_ZONE_EVERY=3
```

## Into the dark: the realms

The climb passes through five realms, and the whole world changes with each one, getting darker,
stranger and more broken, in the spirit of Alice: Madness Returns and Silent Hill. Entering one
shows an "ENTERING ..." card with a chime, and the game-over screen says which realm the run ended
in. A new run starts back in the bright sky.

| Realm | From screen | The walls | Around them |
| --- | --- | --- | --- |
| Rainbow Sky | 0 | Pastel candy with sprinkles | Night sky |
| Twilight | 8 | The old burrow's wallpaper: faded stripes, peeling patches, family portraits hanging on strings, some faces slashed out | A sunset, a pale moon rising, constellations and shooting stars; broken shards of the burrow, still painted with rainbows, start drifting past |
| Ashfall | 18 | Rusted chain-link, rust bleeding down, bolts, cracks leaking violet light | Ash falling through everything, embers rising, the moon a sick orange through the haze; the light fails and flickers now and then |
| The Hollow | 28 | Black stone, twisted roots, a child's chalk scrawls (rainbows, stick bunnies, seven tally marks with the last crossed out, eyes), and shadow hands reaching out of the walls | A thick fog over the way ahead, pale spores; the wall edges start to warp and realm names glitch |
| The Void | 45 to 60 | Black flesh with red veins beating like a heart, eyes watching, teeth along the edges, hands still reaching | The moon eclipsed into a ring of blood red; the edges close in and breathe, and the picture tears in glitching slices with a crackle |

From Twilight on, Pip's lost memories drift through the dark behind the walls: old photographs
of the memory scenes, and torn scraps of paper with pieces of Pip's sentences. They come from the
realms reached so far, and the higher the climb, the more corrupted they are: corners torn away,
slices of the picture slipping sideways, faces scratched out in red, letters breaking into stray
symbols, and in the Void red ghost copies, burnt edges and flicker. Memories not found yet are
blacked out and full of static, with a "?" scratched in, and their words can't be read.

**Pip changes too.** Every memory found greys Pip's fur a little, and the marks build up: a
stitch on the cheek at 4 memories, a torn ear and holes in the wings at 8, a button sewn on for
one eye at 12, stitches down the chest at 16, and the other cheek split and sewn at all 20. The
shop shows each look clean.

The bunny, the trail, coins, shields and the Hollow Ones always stand out. The warped edges and the
teeth are only drawn, and only ever reach a few units into the gap, so the tunnel can look a little
narrower than it is but never wider. Full darkness comes at screen 45 (`darkestAtScreen`) and the Void is deepest at screen
60 (`deepestAtScreen`), both in `tuning.dart`; the realms are spaced out up to `darkestAtScreen`.

- **Music:** five loops play together and crossfade realm by realm, from bright to broken:
  - **day** (Rainbow Sky): bright plucked arpeggios;
  - **dusk** (Twilight): a warm pad;
  - **creep** (Ashfall and The Hollow): the lullaby again on a music box that's out of tune and
    running down: every note wobbles, some are missing, some are a semitone wrong;
  - **night** (under the dark realms): a low drone, wind and echoing bells;
  - **void** (The Void): a heartbeat, a dissonant drone that beats against itself, breaths and
    warped bells.

  The music is quieter on the game-over screen and while a memory is showing. Mute it with the speaker button (bottom-left on the
  title and game-over screens) or the M key. The choice is saved.

The loops are original and generated by `tool/make_music.py` (plain Python, no packages needed). All
five share one tempo, key, chord progression (Am–F–C–G) and length, so they stay in step. To change
the music, edit that script and run:

```bash
python tool/make_music.py
```

## The Last Burrow: memories

The bunny doesn't remember how it got its wings. Its name is Pip, the smallest of seven, and the
dark took its family. As it climbs, its memories come back, darker the higher it goes, until the
Void reveals why every fall starts it again at the bottom.

- **Arrivals:** the first time a run reaches a realm, that realm's memory comes back on its own.
- **Fragments:** each realm also hides three fragments, torn shards of the burrow wall with a
  painted rainbow, glowing teal. They drift close to a wall, so they're hard to reach. At most one
  turns up per realm per run, always the next one in story order.
- **Flashbacks:** when a memory comes back the run pauses. The screen flashes, the frozen world
  washes to sepia with ink at the edges, the music goes quiet, and the memory plays as a little
  animated ink picture in an old frame while its words type themselves out on a torn strip of
  paper. "TAP TO CONTINUE" (or click, Space or Enter) finishes the words, then goes back to the run;
  the bunny waits until you hold again, with a moment of safety. Memories that come back together
  wait their turn.
- **The MEMORIES book** (bottom-centre on the title and game-over screens) keeps every memory found,
  one page per realm. Forgotten ones are left as shadows. The button glows when something new has
  come back.

The story lives in `lib/game/memories.dart`: 20 memories, an arrival and three fragments for each
realm. Text is upper case, in the pixel font's characters (A-Z, 0-9 and `! ? & ' : . , - +`). Each
memory has an `id` that is saved on the device, so never rename one. `memoryChance` in `tuning.dart`
sets how often fragments turn up.

## Sound effects

Short sounds play for:

- **Coins:** a soft, muffled music-box tink, kept quiet; a quick run of coins climbs the scale.
- **The shield:** a quiet, airy swell when you pick one up, and a boing when it takes a hit.
- **The run:** takeoff, crashing, flying past the last crash, every 10 screens and a new best.
- **The Hollow Ones:** a ragged rip and a falling shriek when the shield tears one apart.
- **Realms and memories:** a slow mystic chime on entering a realm, a slightly out-of-tune music box
  when a memory comes back, and crackling static when the picture tears in the Void.
- **Shop and book buttons.**

The speaker button mutes the effects along with the music. Like the music, they are original and
generated, by `tool/make_sfx.py`, in the same key (A minor). To change them, edit that script and
run:

```bash
python tool/make_sfx.py
```

On the web, music and sound effects start with your first tap or click, because browsers block
sound before that.

## Saved on the device

Through `shared_preferences`: the best run, the last run (screens flown and the crash point used for
the ghost marker), the coins in the bank, the shop items bought and worn, the memories found, and
whether the sound is muted.

## Run

```bash
flutter run -d chrome
```

| Platform | Command | Notes |
| --- | --- | --- |
| Web | `flutter run -d chrome` | Fastest for trying changes; hot reload works |
| Android / iOS | `flutter run` with a phone or emulator connected | Portrait only |
| Windows | `flutter run -d windows` | Needs Visual Studio with the "Desktop development with C++" workload |
| macOS | `flutter run -d macos` | Build on a Mac with Xcode |
| Linux | `flutter run -d linux` | Build on Linux with the GTK 3 and GStreamer development packages (GStreamer plays the music) |

`windows/CMakeLists.txt` defines `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` for the
`audioplayers_windows` plugin, which still uses an old coroutine header that recent Visual Studio
versions otherwise refuse to compile.

Desktop windows open phone-shaped (460 × 860). Any other window shape works too: the field gets
side bars on wide windows.

## Test

```bash
flutter test
```

The tests cover:

- The tunnel always leaves room for the bunny, and an autopilot flies past the point where
  difficulty tops out.
- Bonus zones arrive at the configured interval, full of coins, and wide spots still appear late in
  a fast run.
- The shield absorbs a hit, then slows and recovers on schedule.
- Coins, the best run, the last crash and the shop items bought and worn are saved and restored.
- A quick run of coins climbs the scale, and the big moments each make a sound.
- The Hollow Ones wait until screen 25, always leave a way past, end the run (or are torn apart by
  the shield), and hop with a crouch first as a warning.
- The shop sells each item once for coins and puts it on; items that no longer exist are ignored.
- The climb passes through the realms in order, each announced once, and sinks into the Void past
  full darkness; a new run starts back at the bottom.
- Memories come back on arrival and from fragments, in story order, one at a time; in the app a
  memory pauses the run until it's read and the player continues; the story fits the font and its
  paper.
- The trail folds back when the bunny dives.
- The run darkens steadily as you climb, is fully dark at the set screen, and a new run starts
  bright. The music mix moves smoothly from day to night.
- On the Flame side (with `flame_test`):
  - coins and power-ups appear as components and go away when taken;
  - the field follows the screen's shape, from phone to wide window;
  - a crash turns into a particle burst;
  - the speaker button mutes the music and effects instead of starting a run;
  - the shop button opens the shop instead of starting a run, and buying there puts the item on;
  - the shop fits fields from the shortest to the tallest;
  - the sounds the rules ask for get played;
  - the memories book opens, turns its pages and fits every screen shape;
  - the deepest, most broken realm draws without trouble;
  - the picture eases back to bright after a restart instead of flashing.

## How it's put together

The rules live in `GameState`, a plain Dart class with no engine or widget code, so the tests can
drive it directly. `GoingUpGame` (a Flame `FlameGame`) runs it every frame and shows it:

- **Camera:** a `FixedResolutionViewport` that is always 400 units wide, with a height that follows
  the screen. The viewfinder scrolls up the world as you fly, and shakes on a crash.
- **World** (coordinates `(x, -worldY)`, so up the tunnel is up the screen): the trail, tunnel,
  pickups, Hollow Ones, crash marker, particle bursts and bunny.
- **Backdrop:** the starfield, drawn behind the world.
- **Viewport:** the shop, then the HUD, title screen and game-over screen, drawn on top.
- **Input:** `DragCallbacks`. Press, hold and drag anywhere to steer.

| File | What it holds |
| --- | --- |
| `lib/game/game_state.dart` | Rules and state: tunnel, bonus zones, coins, the shield, the Hollow Ones, collision, trail, crash marker, realms, memories, buying and wearing, sound cues |
| `lib/game/tuning.dart` | The knobs: bonus zone interval, shields, the Hollow Ones, darkness, memory fragments |
| `lib/game/stages.dart` | How much of each realm's look is showing, for the walls, sky and air to mix by |
| `lib/game/shop.dart` | What the shop sells: bunny skins (sprite palettes) and trail styles, with prices |
| `lib/game/going_up_game.dart` | The Flame game: camera, world, input, particle bursts |
| `lib/game/memories.dart` | The Last Burrow: the 20 memories, by realm |
| `lib/game/components/` | Flame components: `tunnel` (each realm's walls, warping and teeth), `trail`, `pickups`, `hollows`, `crash_marker`, `bunny` (sprite and wing animation), `starfield` (sunset, moon and eclipse, constellations, shooting stars, burrow shards, mist and motes), `atmosphere` (ash, fog, flicker and vignette), `hud` (with realm cards and memory flashbacks), `shop_screen`, `memories_screen` |
| `lib/game/music.dart` | The layered soundtrack (via `flame_audio`) and its day/dusk/night mix |
| `lib/game/sfx.dart` | Sound effects, played from small `flame_audio` pools |
| `assets/audio/`, `tool/make_music.py` | The three music loops and the script that makes them |
| `assets/audio/sfx/`, `tool/make_sfx.py` | The sound effects and the script that makes them |
| `lib/game/game_screen.dart` | Hosts the `GameWidget` and saves progress (batched) |
| `lib/game/save_store.dart` | Best run, last run and coin total, via `shared_preferences` |
| `lib/game/drawing.dart`, `pixel_font.dart`, `sprites.dart`, `palette.dart` | Shared drawing helpers, pixel font, bunny pixel art, colours |
| `prototypes/` | The earlier HTML and C++ versions of the game, kept for reference |
