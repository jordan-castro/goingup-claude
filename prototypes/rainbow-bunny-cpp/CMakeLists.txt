cmake_minimum_required(VERSION 3.16)
project(RainbowBunny LANGUAGES CXX)

if(NOT WIN32)
  message(FATAL_ERROR "Rainbow Bunny uses the Win32 API for its window, so it builds on Windows only.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(RainbowBunny WIN32
  src/main_win32.cpp
  src/game.cpp
  src/gfx.cpp
)
target_link_libraries(RainbowBunny PRIVATE gdi32 dwmapi)

if(MSVC)
  target_compile_options(RainbowBunny PRIVATE /W4 /permissive-)
else()
  target_compile_options(RainbowBunny PRIVATE -Wall -Wextra)
  # One self-contained .exe that runs without the MinGW runtime DLLs next to it.
  target_link_options(RainbowBunny PRIVATE -static)
endif()
