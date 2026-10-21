#include "gfx.h"

#include <algorithm>
#include <cmath>
#include <cstring>

// ---------- colour ----------

Color hsl(float h, float s, float l) {
    h = std::fmod(h, 360.0f);
    if (h < 0) h += 360.0f;
    const float c = (1.0f - std::fabs(2.0f * l - 1.0f)) * s;
    const float hp = h / 60.0f;
    const float x = c * (1.0f - std::fabs(std::fmod(hp, 2.0f) - 1.0f));
    float r = 0, g = 0, b = 0;
    if (hp < 1)      { r = c; g = x; }
    else if (hp < 2) { r = x; g = c; }
    else if (hp < 3) { g = c; b = x; }
    else if (hp < 4) { g = x; b = c; }
    else if (hp < 5) { r = x; b = c; }
    else             { r = c; b = x; }
    const float m = l - c / 2.0f;
    auto ch = [m](float v) { return int((v + m) * 255.0f + 0.5f); };
    return rgb(ch(r), ch(g), ch(b));
}

Color mix(Color a, Color b, float t) {
    t = std::clamp(t, 0.0f, 1.0f);
    auto lerpCh = [t](Color x, Color y, int shift) {
        const float cx = float((x >> shift) & 255), cy = float((y >> shift) & 255);
        return Color(int(cx + (cy - cx) * t + 0.5f)) << shift;
    };
    return lerpCh(a, b, 16) | lerpCh(a, b, 8) | lerpCh(a, b, 0);
}

// ---------- canvas ----------

Canvas::Canvas(int w, int h) : w_(w), h_(h), px_(std::size_t(w) * h, 0) {}

void Canvas::clear(Color c) { std::fill(px_.begin(), px_.end(), c); }

void Canvas::blend(int x, int y, Color c, float alpha) {
    if (unsigned(x) >= unsigned(w_) || unsigned(y) >= unsigned(h_)) return;
    Color& dst = px_[std::size_t(y) * w_ + x];
    dst = mix(dst, c, alpha);
}

void Canvas::hspan(int y, int x0, int x1, Color c) {
    if (unsigned(y) >= unsigned(h_)) return;
    x0 = std::max(x0, 0);
    x1 = std::min(x1, w_ - 1);
    if (x0 > x1) return;
    Color* row = &px_[std::size_t(y) * w_];
    std::fill(row + x0, row + x1 + 1, c);
}

void Canvas::fillRect(int x, int y, int w, int h, Color c) {
    for (int yy = y; yy < y + h; ++yy) hspan(yy, x, x + w - 1, c);
}

void Canvas::blendRect(int x, int y, int w, int h, Color c, float alpha) {
    for (int yy = std::max(y, 0); yy < std::min(y + h, h_); ++yy)
        for (int xx = std::max(x, 0); xx < std::min(x + w, w_); ++xx) blend(xx, yy, c, alpha);
}

void Canvas::frameRect(int x, int y, int w, int h, Color c) {
    hspan(y, x, x + w - 1, c);
    hspan(y + h - 1, x, x + w - 1, c);
    for (int yy = y + 1; yy < y + h - 1; ++yy) {
        plot(x, yy, c);
        plot(x + w - 1, yy, c);
    }
}

void Canvas::fillConvex(const float* xs, const float* ys, int n, Color c) {
    float ymin = ys[0], ymax = ys[0];
    for (int i = 1; i < n; ++i) {
        ymin = std::min(ymin, ys[i]);
        ymax = std::max(ymax, ys[i]);
    }
    const int y0 = std::max(0, int(std::ceil(ymin - 0.5f)));
    const int y1 = std::min(h_ - 1, int(std::floor(ymax - 0.5f)));
    for (int y = y0; y <= y1; ++y) {
        const float sy = float(y) + 0.5f;
        float xl = 1e9f, xr = -1e9f;
        for (int i = 0; i < n; ++i) {
            const int j = (i + 1) % n;
            const float ya = ys[i], yb = ys[j];
            if (sy < std::min(ya, yb) || sy > std::max(ya, yb)) continue;
            if (ya == yb) {
                xl = std::min({xl, xs[i], xs[j]});
                xr = std::max({xr, xs[i], xs[j]});
                continue;
            }
            const float x = xs[i] + (sy - ya) * (xs[j] - xs[i]) / (yb - ya);
            xl = std::min(xl, x);
            xr = std::max(xr, x);
        }
        if (xl > xr) continue;
        hspan(y, int(std::ceil(xl - 0.5f)), int(std::floor(xr - 0.5f)), c);
    }
}

void Canvas::shift(int dx, int dy, Color fill) {
    if (dx == 0 && dy == 0) return;
    const std::vector<Color> src = px_;
    for (int y = 0; y < h_; ++y) {
        const int sy = y - dy;
        for (int x = 0; x < w_; ++x) {
            const int sx = x - dx;
            const bool inside = unsigned(sx) < unsigned(w_) && unsigned(sy) < unsigned(h_);
            px_[std::size_t(y) * w_ + x] = inside ? src[std::size_t(sy) * w_ + sx] : fill;
        }
    }
}

// ---------- sprites ----------

Sprite::Sprite(std::initializer_list<const char*> rows) {
    h = int(rows.size());
    w = h ? int(std::strlen(*rows.begin())) : 0;
    keys.reserve(std::size_t(w) * h);
    for (const char* row : rows) keys.append(row, std::size_t(w));
}

Sprite Sprite::flippedX() const {
    Sprite s;
    s.w = w; s.h = h; s.keys = keys;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) s.keys[std::size_t(y) * w + x] = keys[std::size_t(y) * w + (w - 1 - x)];
    return s;
}

Sprite Sprite::flippedY() const {
    Sprite s;
    s.w = w; s.h = h; s.keys = keys;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) s.keys[std::size_t(y) * w + x] = keys[std::size_t(h - 1 - y) * w + x];
    return s;
}

Palette::Palette(std::initializer_list<std::pair<char, Color>> entries) {
    for (const auto& [key, col] : entries) colors[key & 127] = col;
}

void drawSprite(Canvas& c, const Sprite& s, const Palette& p, int x, int y, float alpha) {
    for (int yy = 0; yy < s.h; ++yy) {
        for (int xx = 0; xx < s.w; ++xx) {
            const char k = s.keys[std::size_t(yy) * s.w + xx];
            if (k == '.') continue;
            const Color col = p.colors[k & 127];
            if (alpha >= 1.0f) c.plot(x + xx, y + yy, col);
            else c.blend(x + xx, y + yy, col, alpha);
        }
    }
}

// ---------- 5x7 font ----------

namespace {

struct Glyph {
    char ch;
    const char* bits;  // 7 rows of 5 columns, '#' = lit
};

// clang-format off
const Glyph kGlyphs[] = {
    {'A', ".###." "#...#" "#...#" "#####" "#...#" "#...#" "#...#"},
    {'B', "####." "#...#" "#...#" "####." "#...#" "#...#" "####."},
    {'C', ".###." "#...#" "#...." "#...." "#...." "#...#" ".###."},
    {'D', "####." "#...#" "#...#" "#...#" "#...#" "#...#" "####."},
    {'E', "#####" "#...." "#...." "####." "#...." "#...." "#####"},
    {'F', "#####" "#...." "#...." "####." "#...." "#...." "#...."},
    {'G', ".###." "#...#" "#...." "#.###" "#...#" "#...#" ".####"},
    {'H', "#...#" "#...#" "#...#" "#####" "#...#" "#...#" "#...#"},
    {'I', ".###." "..#.." "..#.." "..#.." "..#.." "..#.." ".###."},
    {'J', "..###" "...#." "...#." "...#." "...#." "#..#." ".##.."},
    {'K', "#...#" "#..#." "#.#.." "##..." "#.#.." "#..#." "#...#"},
    {'L', "#...." "#...." "#...." "#...." "#...." "#...." "#####"},
    {'M', "#...#" "##.##" "#.#.#" "#.#.#" "#...#" "#...#" "#...#"},
    {'N', "#...#" "#...#" "##..#" "#.#.#" "#..##" "#...#" "#...#"},
    {'O', ".###." "#...#" "#...#" "#...#" "#...#" "#...#" ".###."},
    {'P', "####." "#...#" "#...#" "####." "#...." "#...." "#...."},
    {'Q', ".###." "#...#" "#...#" "#...#" "#.#.#" "#..#." ".##.#"},
    {'R', "####." "#...#" "#...#" "####." "#.#.." "#..#." "#...#"},
    {'S', ".####" "#...." "#...." ".###." "....#" "....#" "####."},
    {'T', "#####" "..#.." "..#.." "..#.." "..#.." "..#.." "..#.."},
    {'U', "#...#" "#...#" "#...#" "#...#" "#...#" "#...#" ".###."},
    {'V', "#...#" "#...#" "#...#" "#...#" "#...#" ".#.#." "..#.."},
    {'W', "#...#" "#...#" "#...#" "#.#.#" "#.#.#" "#.#.#" ".#.#."},
    {'X', "#...#" "#...#" ".#.#." "..#.." ".#.#." "#...#" "#...#"},
    {'Y', "#...#" "#...#" ".#.#." "..#.." "..#.." "..#.." "..#.."},
    {'Z', "#####" "....#" "...#." "..#.." ".#..." "#...." "#####"},
    {'0', ".###." "#...#" "#..##" "#.#.#" "##..#" "#...#" ".###."},
    {'1', "..#.." ".##.." "..#.." "..#.." "..#.." "..#.." ".###."},
    {'2', ".###." "#...#" "....#" "...#." "..#.." ".#..." "#####"},
    {'3', "#####" "...#." "..#.." "...#." "....#" "#...#" ".###."},
    {'4', "...#." "..##." ".#.#." "#..#." "#####" "...#." "...#."},
    {'5', "#####" "#...." "####." "....#" "....#" "#...#" ".###."},
    {'6', "..##." ".#..." "#...." "####." "#...#" "#...#" ".###."},
    {'7', "#####" "....#" "...#." "..#.." ".#..." ".#..." ".#..."},
    {'8', ".###." "#...#" "#...#" ".###." "#...#" "#...#" ".###."},
    {'9', ".###." "#...#" "#...#" ".####" "....#" "...#." ".##.."},
    {'!', "..#.." "..#.." "..#.." "..#.." "..#.." "....." "..#.."},
    {'?', ".###." "#...#" "....#" "...#." "..#.." "....." "..#.."},
    {'&', ".##.." "#..#." "#.#.." ".#..." "#.#.#" "#..#." ".##.#"},
    {'\'', "..#.." "..#.." ".#..." "....." "....." "....." "....."},
    {':', "....." "..#.." "..#.." "....." "..#.." "..#.." "....."},
    {'.', "....." "....." "....." "....." "....." ".##.." ".##.."},
    {',', "....." "....." "....." "....." ".##.." "..#.." ".#..."},
    {'-', "....." "....." "....." ".###." "....." "....." "....."},
};
// clang-format on

const char* glyphBits(char ch) {
    if (ch >= 'a' && ch <= 'z') ch = char(ch - 'a' + 'A');
    for (const Glyph& g : kGlyphs)
        if (g.ch == ch) return g.bits;
    return nullptr;  // space and anything unknown draw nothing
}

}  // namespace

int textWidth(const std::string& s, int scale) {
    return s.empty() ? 0 : int(s.size()) * 6 * scale - scale;
}

void drawChar(Canvas& c, char ch, int x, int y, int scale, Color col) {
    const char* bits = glyphBits(ch);
    if (!bits) return;
    for (int row = 0; row < 7; ++row)
        for (int column = 0; column < 5; ++column)
            if (bits[row * 5 + column] == '#') c.fillRect(x + column * scale, y + row * scale, scale, scale, col);
}

void drawText(Canvas& c, const std::string& s, int x, int y, int scale, Color col) {
    for (std::size_t i = 0; i < s.size(); ++i) drawChar(c, s[i], x + int(i) * 6 * scale, y, scale, col);
}

void drawTextShadow(Canvas& c, const std::string& s, int x, int y, int scale, Color col, Color shadow) {
    const int off = scale >= 3 ? 2 : 1;
    drawText(c, s, x + off, y + off, scale, shadow);
    drawText(c, s, x, y, scale, col);
}
