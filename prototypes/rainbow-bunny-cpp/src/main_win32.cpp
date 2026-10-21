// Windows platform layer: window, mouse input, frame loop and presenting the pixel buffer.
// Everything game-specific lives in game.cpp, so porting means replacing only this file.

#ifndef UNICODE
#define UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <random>

#include "game.h"

namespace {

Game* g_game = nullptr;
Canvas* g_canvas = nullptr;
HBRUSH g_barBrush = nullptr;

struct View {
    int x, y, w, h;
    float scale;
};

// Fit the play field into the client area. Whole-number scaling keeps every pixel the same size.
View computeView(HWND hwnd) {
    RECT rc;
    GetClientRect(hwnd, &rc);
    const int cw = std::max(1L, rc.right - rc.left), ch = std::max(1L, rc.bottom - rc.top);
    float s = std::min(float(cw) / Game::W, float(ch) / Game::H);
    if (s >= 1.0f) s = std::floor(s);
    const int w = std::max(1, int(Game::W * s)), h = std::max(1, int(Game::H * s));
    return {(cw - w) / 2, (ch - h) / 2, w, h, s};
}

void present(HWND hwnd, HDC dc) {
    const View v = computeView(hwnd);
    RECT rc;
    GetClientRect(hwnd, &rc);
    const RECT bars[4] = {{0, 0, rc.right, v.y},
                          {0, v.y + v.h, rc.right, rc.bottom},
                          {0, v.y, v.x, v.y + v.h},
                          {v.x + v.w, v.y, rc.right, v.y + v.h}};
    for (const RECT& r : bars)
        if (r.right > r.left && r.bottom > r.top) FillRect(dc, &r, g_barBrush);

    BITMAPINFO bmi{};
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = Game::W;
    bmi.bmiHeader.biHeight = -Game::H;  // negative = top-down rows
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;
    SetStretchBltMode(dc, COLORONCOLOR);  // nearest-neighbour scaling
    StretchDIBits(dc, v.x, v.y, v.w, v.h, 0, 0, Game::W, Game::H, g_canvas->data(), &bmi, DIB_RGB_COLORS, SRCCOPY);
}

void toGame(HWND hwnd, LPARAM lp, float& gx, float& gy) {
    const View v = computeView(hwnd);
    gx = float(GET_X_LPARAM(lp) - v.x) / v.scale;
    gy = float(GET_Y_LPARAM(lp) - v.y) / v.scale;
}

// Windows turns touch and pen input into mouse messages and tags them with this signature.
bool fromTouch() { return (GetMessageExtraInfo() & 0xFFFFFF00) == 0xFF515700; }

LRESULT CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    float gx = 0, gy = 0;
    switch (msg) {
    case WM_LBUTTONDOWN:
        SetCapture(hwnd);  // keep steering even if the cursor leaves the window
        toGame(hwnd, lp, gx, gy);
        g_game->pointerDown(gx, gy, fromTouch());
        return 0;
    case WM_MOUSEMOVE:
        toGame(hwnd, lp, gx, gy);
        g_game->pointerMove(gx, gy);
        return 0;
    case WM_LBUTTONUP:
        g_game->pointerUp();
        ReleaseCapture();
        return 0;
    case WM_CAPTURECHANGED:
    case WM_KILLFOCUS:
        g_game->pointerUp();
        return 0;
    case WM_KEYDOWN:
        if (wp == VK_ESCAPE) {
            DestroyWindow(hwnd);
            return 0;
        }
        break;
    case WM_GETMINMAXINFO: {
        auto* info = reinterpret_cast<MINMAXINFO*>(lp);
        info->ptMinTrackSize = {Game::W + 40, Game::H + 60};
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC dc = BeginPaint(hwnd, &ps);
        present(hwnd, dc);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

}  // namespace

int WINAPI WinMain(HINSTANCE instance, HINSTANCE, LPSTR, int showCmd) {
    SetProcessDPIAware();  // we scale ourselves; stop Windows from blurring the window

    wchar_t exePath[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    const std::filesystem::path savePath = std::filesystem::path(exePath).parent_path() / "rainbow_bunny_save.txt";

    std::random_device rd;
    static Game game(savePath, rd() ^ unsigned(GetTickCount()));
    static Canvas canvas(Game::W, Game::H);
    g_game = &game;
    g_canvas = &canvas;
    g_barBrush = CreateSolidBrush(RGB(12, 10, 26));

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = wndProc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursor(nullptr, IDC_CROSS);
    wc.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
    wc.lpszClassName = L"RainbowBunnyWindow";
    RegisterClassExW(&wc);

    // Biggest whole-number scale that fits the screen's work area.
    RECT work;
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
    const int workW = work.right - work.left, workH = work.bottom - work.top;
    const int scale = std::max(1, std::min((workH - 80) / Game::H, (workW - 40) / Game::W));
    const DWORD style = WS_OVERLAPPEDWINDOW;
    RECT wr{0, 0, Game::W * scale, Game::H * scale};
    AdjustWindowRect(&wr, style, FALSE);
    const int ww = wr.right - wr.left, wh = wr.bottom - wr.top;

    HWND hwnd = CreateWindowExW(0, wc.lpszClassName, L"Rainbow Bunny", style, work.left + (workW - ww) / 2,
                                work.top + (workH - wh) / 2, ww, wh, nullptr, nullptr, instance, nullptr);
    if (!hwnd) return 1;
    ShowWindow(hwnd, showCmd);
    UpdateWindow(hwnd);

    LARGE_INTEGER freq, last, now;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&last);

    bool running = true;
    while (running) {
        MSG msg;
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) running = false;
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        if (!running) break;
        if (IsIconic(hwnd)) {  // minimised: sleep until something happens
            WaitMessage();
            QueryPerformanceCounter(&last);
            continue;
        }

        QueryPerformanceCounter(&now);
        const double dt = double(now.QuadPart - last.QuadPart) / double(freq.QuadPart);
        last = now;
        game.update(dt);
        game.draw(canvas);

        HDC dc = GetDC(hwnd);
        present(hwnd, dc);
        ReleaseDC(hwnd, dc);
        if (FAILED(DwmFlush())) Sleep(8);  // DwmFlush waits for the next screen refresh
    }

    DeleteObject(g_barBrush);
    return 0;
}
