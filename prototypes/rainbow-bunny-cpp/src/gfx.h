// Tiny software renderer: a 32-bit pixel buffer plus the handful of primitives the game needs.
#pragma once

#include <cstdint>
#include <initializer_list>
#include <string>
#include <utility>
#include <vector>

using Color = std::uint32_t;  // 0x00RRGGBB, the layout a 32-bit Windows DIB expects

constexpr Color rgb(int r, int g, int b) {
    return (Color(r & 255) << 16) | (Color(g & 255) << 8) | Color(b & 255);
}
Color hsl(float hueDeg, float sat, float light);
Color mix(Color a, Color b, float t);  // t = 0 gives a, t = 1 gives b

class Canvas {
public:
    Canvas(int w, int h);

    int width() const { return w_; }
    int height() const { return h_; }
    const Color* data() const { return px_.data(); }

    void clear(Color c);
    void plot(int x, int y, Color c) {
        if (unsigned(x) < unsigned(w_) && unsigned(y) < unsigned(h_)) px_[std::size_t(y) * w_ + x] = c;
    }
    void blend(int x, int y, Color c, float alpha);
    void hspan(int y, int x0, int x1, Color c);  // inclusive, clipped
    void fillRect(int x, int y, int w, int h, Color c);
    void blendRect(int x, int y, int w, int h, Color c, float alpha);
    void frameRect(int x, int y, int w, int h, Color c);  // 1 px outline
    // Fills every pixel whose centre lies inside the polygon. Meant for small convex shapes.
    void fillConvex(const float* xs, const float* ys, int n, Color c);
    // Moves the whole image by (dx, dy), filling the uncovered edge with `fill`.
    void shift(int dx, int dy, Color fill);

private:
    int w_, h_;
    std::vector<Color> px_;
};

// Pixel-art sprite: one char per pixel, '.' is transparent, any other char is a palette key.
struct Sprite {
    int w = 0, h = 0;
    std::string keys;

    Sprite(std::initializer_list<const char*> rows);
    Sprite flippedX() const;
    Sprite flippedY() const;

private:
    Sprite() = default;
};

struct Palette {
    Color colors[128] = {};
    Palette(std::initializer_list<std::pair<char, Color>> entries);
};

void drawSprite(Canvas& c, const Sprite& s, const Palette& p, int x, int y, float alpha = 1.0f);

// Built-in 5x7 pixel font (A-Z, 0-9 and a little punctuation). Each glyph advances 6 * scale.
int textWidth(const std::string& s, int scale);
void drawChar(Canvas& c, char ch, int x, int y, int scale, Color col);
void drawText(Canvas& c, const std::string& s, int x, int y, int scale, Color col);
void drawTextShadow(Canvas& c, const std::string& s, int x, int y, int scale, Color col, Color shadow);
