@echo off
rem Builds build\RainbowBunny.exe with MinGW-w64 g++ (for example the one from MSYS2).
cd /d "%~dp0"
if not exist build mkdir build
g++ -std=c++17 -O2 -Wall -Wextra src\main_win32.cpp src\game.cpp src\gfx.cpp -o build\RainbowBunny.exe -mwindows -lgdi32 -ldwmapi -static
if errorlevel 1 exit /b 1
echo Built build\RainbowBunny.exe
