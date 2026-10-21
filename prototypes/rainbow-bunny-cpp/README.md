# Rainbow Bunny (C++)

A winged pixel bunny flies up an endless tunnel. Hold the left mouse button and the bunny follows
your cursor; let go and it stays put. Touch a wall and the run ends. The tunnel speeds up the
longer you survive, slowly at first and then faster. The top-right counter shows how many
screens you have flown past.

After a crash, the next run shows a "LAST CRASH" line with a ghost bunny at the height where you
went down, so you can see when you pass it.

Esc closes the game. Your best score and last crash point are saved in
`rainbow_bunny_save.txt` next to the .exe.

## Build

Windows only: the window and input use the Win32 API, and there are no other dependencies.

**MinGW-w64 g++ (MSYS2):** double-click `build.cmd`, or run:

```bat
g++ -std=c++17 -O2 src\main_win32.cpp src\game.cpp src\gfx.cpp -o build\RainbowBunny.exe -mwindows -lgdi32 -ldwmapi -static
```

**CMake (Visual Studio or MinGW):**

```bat
cmake -S . -B build
cmake --build build --config Release
```

If CMake's compiler check fails with a note about object paths longer than 250 characters, the
folder path is too long for Windows. Move the project somewhere shorter, or pass a short build
folder such as `-B C:\tmp\rb-build`.

## Layout

| File | What it holds |
| --- | --- |
| `src/game.h`, `src/game.cpp` | Game rules, tunnel generation, collision, trail, crash marker, all drawing |
| `src/gfx.h`, `src/gfx.cpp` | Small software renderer: pixel buffer, shapes, sprites, 5x7 pixel font |
| `src/main_win32.cpp` | Window, mouse input, frame loop, scaling the 200x360 pixel buffer to the window |

`game.cpp` and `gfx.cpp` don't touch the operating system, so porting the game (to SDL or raylib,
for example) means replacing only `main_win32.cpp`.

## Look

Everything is drawn into a 200x360 pixel buffer and scaled up by a whole number with
nearest-neighbour sampling, so pixels stay square and crisp. It uses flat fills and a muted
palette, with no glows, gradients or screen flashes.
