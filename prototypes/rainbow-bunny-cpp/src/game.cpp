#include "game.h"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <utility>

namespace {

constexpr float FW = float(Game::W), FH = float(Game::H);
constexpr float kPi = 3.14159265f;

constexpr float BASE_SPEED = 95.0f, MAX_SPEED = 625.0f;  // world pixels per second
constexpr float FOLLOW = 15.0f;                          // how snappily the bunny chases the pointer
constexpr float STEP = 4.0f;                             // spacing of wall samples
constexpr float TRAIL_W = 12.0f, TRAIL_SW = 2.0f;        // six 2 px stripes
constexpr float OVER_DELAY = 0.45f, RETRY_DELAY = 0.95f;

// Matte palette: flat fills, no glows.
constexpr Color kBg = rgb(27, 26, 56);
constexpr Color kInk = rgb(34, 24, 52);
constexpr Color kStarDim = rgb(84, 86, 128);
constexpr Color kStarMid = rgb(140, 142, 186);
constexpr Color kStarBright = rgb(214, 214, 236);
constexpr Color kPanel = rgb(18, 15, 38);
constexpr Color kPanelEdge = rgb(206, 200, 232);
constexpr Color kText = rgb(242, 238, 250);
constexpr Color kMuted = rgb(176, 168, 208);
constexpr Color kSun = rgb(236, 204, 98);
constexpr Color kHot = rgb(214, 92, 140);
constexpr Color kLine = rgb(214, 208, 236);

constexpr Color kRainbow[6] = {rgb(218, 86, 96),  rgb(230, 148, 78), rgb(228, 204, 86),
                               rgb(110, 186, 108), rgb(84, 156, 212), rgb(140, 114, 206)};
constexpr Color kLogo[7] = {rgb(218, 86, 96),  rgb(230, 148, 78), rgb(228, 204, 86), rgb(110, 186, 108),
                            rgb(84, 156, 212), rgb(140, 114, 206), rgb(222, 120, 184)};
constexpr Color kSprinkles[7] = {rgb(206, 80, 110), rgb(222, 186, 80), rgb(80, 180, 150), rgb(78, 150, 206),
                                 rgb(150, 110, 200), rgb(240, 236, 248), rgb(220, 130, 80)};
constexpr Color kGhostSpark[4] = {rgb(220, 228, 250), rgb(206, 184, 246), rgb(236, 204, 98), rgb(242, 238, 250)};

// The bunny's anchor (bx, by) is the pixel at column 8, row 14 of this sprite.
const Sprite kBunny{
    "...kkk....kkk...",
    "..kwwwk..kwwwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwwwkkkkwwwk..",
    ".kwwwwwwwwwwwwk.",
    "kwwwwwwwwwwwwwwk",
    "kwwkkwwwwwwkkwwk",
    "kwwkkwwwwwwkkwwk",
    "kwccwwwnnwwwccwk",
    "kwwwwwwmmwwwwwwk",
    ".kwwwwmwwmwwwwk.",
    "..kkwwwwwwwwkk..",
    "..kwwwwwwwwwwk..",
    ".kwkwwwggwwwkwk.",
    ".kwkwwggggwwkwk.",
    ".kkkwwggggwwkkk.",
    "..kwwwggggwwwk..",
    "..kwwwwggwwwwk..",
    "..kwwkkkkkkwwk..",
    "..kppk....kppk..",
    "..kkkk....kkkk..",
};

// Same bunny with X eyes, used for the last run's crash marker.
const Sprite kGhost{
    "...kkk....kkk...",
    "..kwwwk..kwwwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwpwk..kwpwk..",
    "..kwwwkkkkwwwk..",
    ".kwwwwwwwwwwwwk.",
    "kwkwkwwwwwwkwkwk",
    "kwwkwwwwwwwwkwwk",
    "kwkwkwwwwwwkwkwk",
    "kwccwwwnnwwwccwk",
    "kwwwwwwmmwwwwwwk",
    ".kwwwwmwwmwwwwk.",
    "..kkwwwwwwwwkk..",
    "..kwwwwwwwwwwk..",
    ".kwkwwwggwwwkwk.",
    ".kwkwwggggwwkwk.",
    ".kkkwwggggwwkkk.",
    "..kwwwggggwwwk..",
    "..kwwwwggwwwwk..",
    "..kwwkkkkkkwwk..",
    "..kppk....kppk..",
    "..kkkk....kkkk..",
};

const Sprite kWingUpL{
    "kk.....",
    "kbkk...",
    "kbbbkk.",
    ".kbbbbk",
    "..kbbbk",
    "...kkkk",
};
const Sprite kWingDownL = kWingUpL.flippedY();
const Sprite kWingUpR = kWingUpL.flippedX();
const Sprite kWingDownR = kWingDownL.flippedX();

const Sprite kHalo{
    ".yyyyyyy.",
    "y.......y",
    ".yyyyyyy.",
};

const Palette kBunnyPal{{'k', kInk},
                        {'w', rgb(246, 244, 250)},
                        {'g', rgb(224, 218, 240)},
                        {'p', rgb(238, 164, 200)},
                        {'c', rgb(236, 150, 186)},
                        {'n', rgb(222, 96, 140)},
                        {'m', rgb(168, 82, 122)},
                        {'b', rgb(192, 224, 242)}};
const Palette kGhostPal{{'k', rgb(108, 127, 209)}, {'w', rgb(227, 236, 255)}, {'g', rgb(195, 210, 251)},
                        {'p', rgb(217, 184, 255)}, {'c', rgb(217, 184, 255)}, {'n', rgb(185, 156, 255)},
                        {'m', rgb(138, 127, 216)}};
const Palette kHaloPal{{'y', kSun}};

float lerp(float a, float b, float t) { return a + (b - a) * t; }

float hash01(int n) {
    const double x = std::sin(double(n) * 127.1 + 311.7) * 43758.5453;
    return float(x - std::floor(x));
}

float catmull(float p0, float p1, float p2, float p3, float t) {
    const float t2 = t * t, t3 = t2 * t;
    return 0.5f * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
}

bool blinkOn(double t) { return std::fmod(t, 1.1) < 0.75; }

void panel(Canvas& c, int x, int y, int w, int h) {
    c.blendRect(x, y, w, h, kPanel, 0.85f);
    c.frameRect(x, y, w, h, kPanelEdge);
}

void centered(Canvas& c, const std::string& s, int y, int scale, Color col) {
    drawText(c, s, (Game::W - textWidth(s, scale)) / 2, y, scale, col);
}

void centeredShadow(Canvas& c, const std::string& s, int y, int scale, Color col, Color shadow) {
    drawTextShadow(c, s, (Game::W - textWidth(s, scale)) / 2, y, scale, col, shadow);
}

}  // namespace

// ---------- setup ----------

Game::Game(std::filesystem::path savePath, unsigned seed)
    : savePath_(std::move(savePath)), rng_(seed), bx_(FW / 2), by_(FH * 0.7f), tx_(bx_), ty_(by_) {
    for (int i = 0; i < 60; ++i) {
        Star s;
        s.x = rand(0, FW);
        s.y = rand(0, FH);
        s.z = rand(0.05f, 0.38f);
        s.phase = rand(0, 8);
        s.big = rand(0, 1) < 0.12f;
        stars_.push_back(s);
    }
    load();
    resetWorld();
}

float Game::rand(float a, float b) {
    if (!(a < b)) return a;
    return std::uniform_real_distribution<float>(a, b)(rng_);
}

void Game::load() {
    std::ifstream f(savePath_);
    std::string key;
    while (f >> key) {
        if (key == "best") {
            f >> best_;
        } else if (key == "last") {
            if (f >> crashWy_ >> crashX_) hasCrash_ = true;
        }
    }
    best_ = std::max(best_, 0);
}

void Game::save() const {
    std::ofstream f(savePath_);
    if (!f) return;
    f << "best " << best_ << "\n";
    if (hasCrash_) f << "last " << crashWy_ << " " << crashX_ << "\n";
}

// ---------- input ----------

void Game::pointerDown(float x, float y, bool touch) {
    touchOffset_ = touch ? 35.0f : 0.0f;  // keep the bunny visible above a finger
    holding_ = true;
    pointerMove(x, y);
    if (mode_ == Mode::Title) startGame();
    else if (mode_ == Mode::Dead && deadT_ > RETRY_DELAY) startGame();
}

void Game::pointerMove(float x, float y) {
    if (!holding_) return;
    tx_ = std::clamp(x, 0.0f, FW);
    ty_ = std::clamp(y - touchOffset_, 0.0f, FH);
}

void Game::pointerUp() { holding_ = false; }

// ---------- flow ----------

void Game::startGame() {
    mode_ = Mode::Playing;
    runT_ = 0;
    D_ = 0;
    speed_ = BASE_SPEED;
    screens_ = 0;
    grace_ = 1.0f;
    bx_ = FW / 2;
    by_ = FH * 0.72f;
    trail_.clear();
    particles_.clear();
    shake_ = 0;
    toastT_ = 0;
    newBest_ = false;
    hasMarker_ = hasCrash_;
    if (hasCrash_) marker_ = {crashWy_, crashX_, 1.0f, false};
    resetWorld();
}

void Game::die() {
    mode_ = Mode::Dead;
    deadT_ = 0;
    shake_ = 1;
    burst(bx_, by_, 70, kRainbow, 6, 30, 260, 0.5f);
    crashWy_ = float(D_) + FH - by_;
    crashX_ = bx_;
    hasCrash_ = true;
    newBest_ = screens_ > best_;
    if (newBest_) best_ = screens_;
    save();
}

void Game::onNewScreen(int s) {
    popT_ = 0.25f;
    if (best_ > 0 && s == best_ + 1) {
        showToast("NEW BEST!");
        burst(FW / 2, FH * 0.3f, 36, kSprinkles, 7, 40, 190, 0.3f);
    } else if (s > 0 && s % 10 == 0) {
        showToast(std::to_string(s) + " SCREENS!");
        burst(FW / 2, FH * 0.3f, 36, kSprinkles, 7, 40, 190, 0.3f);
    }
}

void Game::showToast(std::string text) {
    toast_ = std::move(text);
    toastT_ = 1.6f;
}

void Game::burst(float x, float y, int count, const Color* colors, int colorCount, float minSpeed, float maxSpeed,
                 float scroll) {
    for (int i = 0; i < count; ++i) {
        const float a = rand(0, 2 * kPi), sp = rand(minSpeed, maxSpeed);
        Particle p;
        p.x = x + rand(-4, 4);
        p.y = y + rand(-7, 7);
        p.vx = std::cos(a) * sp;
        p.vy = std::sin(a) * sp;
        p.life = rand(0.6f, 1.4f);
        p.maxLife = 1.4f;
        p.size = rand(1, 3);
        p.drag = 2.4f;
        p.scroll = scroll;
        p.color = colors[i % colorCount];
        particles_.push_back(p);
    }
}

// ---------- tunnel ----------
// Control points hold a centre line and a gap width; Catmull-Rom curves join them.

float Game::difficulty() const { return std::min(1.0f, float(screens_) / 40.0f); }

Game::Control Game::makeControl(const Control& prev) {
    if (mode_ == Mode::Title) return {prev.w + rand(150, 210), FW / 2 + rand(-18, 18), rand(142, 165)};
    const float d = difficulty();
    const float vNorm = std::clamp((speed_ - BASE_SPEED) / (MAX_SPEED - BASE_SPEED), 0.0f, 1.0f);
    const float gMin = lerp(85, 52, d), gMax = lerp(145, 105, d);
    const float g = rand(0, 1) < lerp(0.25f, 0.45f, d) ? gMin + rand(0, 7) : rand(gMin, gMax);
    const float shift = lerp(55, 87, d);
    const float lo = g / 2 + 7, hi = FW - g / 2 - 7;
    // wander toward a random spot, but never further than `shift` in one stretch
    float c = prev.c + std::clamp(rand(lo, hi) - prev.c, -shift, shift);
    c = std::clamp(c, lo, hi);
    return {prev.w + rand(130, 210) * (1 + 0.65f * vNorm), c, g};
}

void Game::ensureControls(std::size_t n) {
    while (controls_.size() <= n) controls_.push_back(makeControl(controls_.back()));
}

Game::WallSample Game::sampleWall(float w) {
    ensureControls(ctrlIdx_ + 2);
    while (controls_[ctrlIdx_ + 1].w <= w) {
        ++ctrlIdx_;
        ensureControls(ctrlIdx_ + 2);
    }
    if (ctrlIdx_ > 6) {
        controls_.erase(controls_.begin(), controls_.begin() + std::ptrdiff_t(ctrlIdx_ - 2));
        ctrlIdx_ = 2;
    }
    const Control& p0 = controls_[ctrlIdx_ > 0 ? ctrlIdx_ - 1 : 0];
    const Control& p1 = controls_[ctrlIdx_];
    const Control& p2 = controls_[ctrlIdx_ + 1];
    const Control& p3 = controls_[ctrlIdx_ + 2];
    const float t = (w - p1.w) / (p2.w - p1.w);
    float c = catmull(p0.c, p1.c, p2.c, p3.c, t);
    const float g = std::max(48.0f, catmull(p0.g, p1.g, p2.g, p3.g, t));
    c += std::sin(w * 0.042f + wobble_) * 2.0f * (0.5f + difficulty());
    float l = c - g / 2, r = c + g / 2;
    if (l < 5) { r += 5 - l; l = 5; }
    if (r > FW - 5) { l -= r - (FW - 5); r = FW - 5; }
    return {w, std::max(5.0f, l), r, sampleK_++};
}

void Game::fillWalls() {
    const float need = float(D_) + FH + 40;
    while (nextW_ <= need) {
        walls_.push_back(sampleWall(nextW_));
        nextW_ += STEP;
    }
    while (walls_.size() > 3 && walls_[1].w < float(D_) - 30) walls_.pop_front();
}

void Game::resetWorld() {
    const float g0 = FW - 20;
    controls_ = {{-350, FW / 2, g0}, {-150, FW / 2, g0}, {FH * 0.95f, FW / 2, FW - 28}};
    ctrlIdx_ = 0;
    walls_.clear();
    sampleK_ = 0;
    nextW_ = float(D_) - 60;
    wobble_ = rand(0, 6.28f);
    fillWalls();
}

void Game::wallAtWorld(float wy, float& l, float& r) const {
    const float f = (wy - walls_.front().w) / STEP;
    const int i = int(std::floor(f));
    if (i < 0) {
        l = walls_.front().l;
        r = walls_.front().r;
        return;
    }
    if (i >= int(walls_.size()) - 1) {
        l = walls_.back().l;
        r = walls_.back().r;
        return;
    }
    const float t = f - float(i);
    const WallSample& a = walls_[std::size_t(i)];
    const WallSample& b = walls_[std::size_t(i) + 1];
    l = a.l + (b.l - a.l) * t;
    r = a.r + (b.r - a.r) * t;
}

// Two circles (head and body) checked against the walls; the ears are left out on purpose.
bool Game::hitsWall() const {
    static const float parts[2][2] = {{-2.5f, 7.0f}, {5.5f, 6.2f}};  // {y offset, radius}
    static const float steps[] = {-1.0f, -0.7f, -0.35f, 0.0f, 0.35f, 0.7f, 1.0f};
    for (const auto& part : parts) {
        const float cy = by_ + part[0], radius = part[1];
        for (float f : steps) {
            const float halfChord = radius * std::sqrt(std::max(0.0f, 1 - f * f));
            float l, r;
            wallAtWorld(float(D_) + FH - (cy + f * radius), l, r);
            if (bx_ - halfChord < l || bx_ + halfChord > r) return true;
        }
    }
    return false;
}

float Game::tailWorldY() const { return float(D_) + FH - (by_ + 8.0f); }

// ---------- simulation ----------

void Game::update(double dt) {
    if (!(dt > 0)) return;
    dt = std::min(dt, 0.05);
    const int n = int(std::ceil(dt * 120.0));  // fixed-ish substeps so fast runs can't skip a wall
    const float h = float(dt / n);
    for (int i = 0; i < n; ++i) tick(h);
}

void Game::tick(float h) {
    time_ += h;
    if (mode_ == Mode::Playing) {
        runT_ += h;
        const float t = float(runT_);
        speed_ = std::min(MAX_SPEED, BASE_SPEED + 2.0f * t + 0.0375f * t * t);  // slow at first, then faster
    } else if (mode_ == Mode::Title) {
        speed_ = 55;
    } else {
        speed_ *= std::exp(-2.2f * h);
        deadT_ += h;
    }
    const float dy = speed_ * h;
    D_ += dy;
    fillWalls();

    if (mode_ == Mode::Playing && holding_) {
        const float k = 1 - std::exp(-FOLLOW * h);
        bx_ = std::clamp(bx_ + (tx_ - bx_) * k, 9.0f, FW - 9);
        by_ = std::clamp(by_ + (ty_ - by_) * k, 40.0f, FH - 20);
    } else if (mode_ == Mode::Title) {
        const float k = 1 - std::exp(-3.0f * h);
        bx_ += (FW / 2 - bx_) * k;
        by_ += (FH * 0.7f - by_) * k;
    }

    for (Star& s : stars_) {
        s.y += dy * s.z;
        if (s.y > FH + 4) {
            s.y -= FH + 8;
            s.x = rand(0, FW);
        }
    }
    for (std::size_t i = 0; i < particles_.size();) {
        Particle& p = particles_[i];
        p.life -= h;
        if (p.life <= 0) {
            particles_[i] = particles_.back();
            particles_.pop_back();
            continue;
        }
        const float dragF = std::exp(-p.drag * h);
        p.vx *= dragF;
        p.vy *= dragF;
        p.x += p.vx * h;
        p.y += p.vy * h + dy * p.scroll;
        ++i;
    }

    // Rainbow trail: points live in world space, oldest first, always rising in world y.
    // Flying down faster than the scroll eats back into the trail so it stays attached.
    if (mode_ != Mode::Dead) {
        const float tw = tailWorldY();
        while (!trail_.empty() && trail_.back().wy > tw) trail_.pop_back();
        if (trail_.empty() || tw - trail_.back().wy >= 1.5f || std::fabs(bx_ - trail_.back().x) >= 1.0f)
            trail_.push_back({tw, bx_});
    }
    while (trail_.size() > 2 && trail_[1].wy < float(D_) - 10) trail_.pop_front();

    if (hasMarker_) {
        if (mode_ == Mode::Playing && !marker_.passed && float(D_) + FH - by_ > marker_.wy) {
            marker_.passed = true;
            burst(marker_.x, float(FH - (marker_.wy - D_)), 30, kGhostSpark, 4, 30, 150, 1.0f);
        }
        if (marker_.passed) marker_.fade = std::max(0.0f, marker_.fade - h * 1.4f);
    }

    if (mode_ == Mode::Playing) {
        const int s = int(std::floor(D_ / FH));
        if (s != screens_) {
            screens_ = s;
            onNewScreen(s);
        }
        if (grace_ > 0) {
            grace_ -= h;
        } else if (hitsWall()) {
            die();
            return;
        }
    }

    shake_ = std::max(0.0f, shake_ - h * 2.6f);
    popT_ = std::max(0.0f, popT_ - h);
    toastT_ = std::max(0.0f, toastT_ - h);
}

// ---------- drawing ----------

void Game::draw(Canvas& c) {
    const double dr = std::floor(D_);  // scroll in whole pixels so the pixel art stays crisp

    c.clear(kBg);
    for (const Star& s : stars_) {
        const int x = int(s.x), y = int(s.y);
        if (s.big) {
            c.plot(x, y, kStarBright);
            if (std::fmod(time_ * 1.2 + s.phase, 3.0) < 2.0) {
                c.plot(x - 1, y, kStarMid);
                c.plot(x + 1, y, kStarMid);
                c.plot(x, y - 1, kStarMid);
                c.plot(x, y + 1, kStarMid);
            }
        } else {
            c.plot(x, y, s.z > 0.25f ? kStarMid : kStarDim);
        }
    }

    drawTrail(c, dr);
    drawWalls(c, dr);
    drawMarker(c, dr);
    for (const Particle& p : particles_) {
        const float a = std::clamp(p.life / (p.maxLife * 0.5f), 0.0f, 1.0f);
        const int sz = std::max(1, int(std::lround(p.size)));
        c.blendRect(int(std::lround(p.x)) - sz / 2, int(std::lround(p.y)) - sz / 2, sz, sz, p.color, a);
    }
    drawBunny(c);

    if (shake_ > 0) {
        const float amp = shake_ * 3.0f;
        c.shift(int(std::lround(rand(-amp, amp))), int(std::lround(rand(-amp, amp))), kBg);
    }

    drawHud(c);
    if (mode_ == Mode::Title) drawTitle(c);
    if (mode_ == Mode::Dead) drawGameOver(c);
}

void Game::drawWalls(Canvas& c, double dr) const {
    int xl[H], xr[H];
    Color fill[H];
    for (int y = 0; y < H; ++y) {
        const float wy = float(dr) + FH - (float(y) + 0.5f);
        float l, r;
        wallAtWorld(wy, l, r);
        xl[y] = int(std::lround(l));
        xr[y] = int(std::lround(r));
        fill[y] = hsl(wy * 0.2f, 0.42f, 0.66f);  // soft pastel that drifts through the rainbow
    }
    for (int y = 0; y < H; ++y) {
        c.hspan(y, 0, xl[y] - 1, fill[y]);
        c.hspan(y, xr[y], W - 1, fill[y]);
        // 1 px outline that stays unbroken where the wall runs nearly sideways
        const int up = y > 0 ? y - 1 : y, down = y < H - 1 ? y + 1 : y;
        c.hspan(y, std::min({xl[y], xl[up], xl[down]}) - 1, xl[y] - 1, kInk);
        c.hspan(y, xr[y], std::max({xr[y], xr[up], xr[down]}), kInk);
    }

    // sprinkles, kept a couple of pixels inside the outline
    auto sprinkle = [&](int x, int y, int k, bool leftWall) {
        static const int shapes[4][3][2] = {{{-1, 0}, {0, 0}, {1, 0}},
                                            {{0, -1}, {0, 0}, {0, 1}},
                                            {{-1, -1}, {0, 0}, {1, 1}},
                                            {{-1, 1}, {0, 0}, {1, -1}}};
        const auto& shape = shapes[int(hash01(k + 3) * 4) & 3];
        const Color col = kSprinkles[int(hash01(k + 7) * 7) % 7];
        for (const auto& o : shape) {
            const int px = x + o[0], py = y + o[1];
            if (py < 0 || py >= H) continue;
            if (leftWall ? px < xl[py] - 2 : px > xr[py] + 1) c.plot(px, py, col);
        }
    };
    for (const WallSample& s : walls_) {
        if (s.k % 3) continue;
        const int y = int(std::lround(FH - (s.w - dr)));
        if (y < 0 || y >= H) continue;
        if (s.l > 14) sprinkle(int(3 + hash01(s.k) * (s.l - 12)), y, s.k, true);
        const float rw = FW - s.r;
        if (rw > 14) sprinkle(int(s.r + 8 + hash01(s.k + 5) * (rw - 12)), y + 2, s.k + 11, false);
    }
}

// The trail is one continuous ribbon. Each stripe is offset along the path's normal, so it keeps
// its full width through any turn, and every stripe edge on a straight run lands on a whole pixel.
void Game::drawTrail(Canvas& c, double dr) {
    if (trail_.empty()) return;
    const bool alive = mode_ != Mode::Dead;
    const std::size_t n = trail_.size();
    const float headW = alive ? std::max(tailWorldY(), trail_.back().wy) : trail_.back().wy;
    const float headX = alive ? bx_ : trail_.back().x;
    const long waveTick = long(std::floor(time_ * 9));

    std::size_t j = n - 1;
    auto xAt = [&](float wy) {
        const TrailPoint& a = trail_[n - 1];
        if (wy >= a.wy) return headW > a.wy ? a.x + (headX - a.x) * (wy - a.wy) / (headW - a.wy) : headX;
        while (j > 0 && trail_[j - 1].wy > wy) --j;
        if (j == 0) return trail_[0].x;
        const TrailPoint& p = trail_[j - 1];
        const TrailPoint& b = trail_[j];
        return b.wy > p.wy ? p.x + (b.x - p.x) * (wy - p.wy) / (b.wy - p.wy) : b.x;
    };

    // centre line: one vertex per pixel row of world space
    rawX_.clear();
    rx_.clear();
    ry_.clear();
    rw_.clear();
    const float bottomW = std::max(trail_.front().wy, float(dr) - 3);
    for (long k = long(std::ceil(headW)); float(k) >= bottomW; --k) {
        rawX_.push_back(xAt(float(k)));
        rx_.push_back(std::round(rawX_.back()));
        ry_.push_back(float(FH - (double(k) - dr)));
        const long block = long(std::floor(double(k) / 3.0));  // the Nyan wiggle, in 3-row blocks
        rw_.push_back((block + waveTick) % 2 != 0 ? 1.0f : 0.0f);
    }
    const std::size_t m = rx_.size();
    if (m < 2) return;

    // Stripe direction per row, from the unrounded path a few rows either side so whole-pixel
    // rounding can't kink it. Gentle slants keep the stripes as plain pixel columns that step
    // sideways; steep swerves turn them with the path so the ribbon keeps its width.
    nx_.assign(m, 1.0f);
    ny_.assign(m, 0.0f);
    for (std::size_t i = 0; i < m; ++i) {
        const std::size_t i0 = i >= 3 ? i - 3 : 0, i1 = std::min(m - 1, i + 3);
        const float dx = rawX_[i1] - rawX_[i0], dy = ry_[i1] - ry_[i0];
        const float len = std::hypot(dx, dy);
        if (len < 1e-4f) continue;
        const float slope = std::fabs(dx) / std::max(dy, 1e-4f);
        const float t = std::clamp((slope - 0.35f) / 0.55f, 0.0f, 1.0f);
        const float turn = t * t * (3 - 2 * t);  // smoothstep
        // normal pointing to the ribbon's left side (red), for a path heading down the screen
        float ux = lerp(1.0f, dy / len, turn), uy = lerp(0.0f, -dx / len, turn);
        const float ul = std::hypot(ux, uy);
        nx_[i] = ux / ul;
        ny_[i] = uy / ul;
    }

    // one quad per stripe per row; a segment keeps its row's wiggle so the steps stay blocky
    for (std::size_t i = 0; i + 1 < m; ++i) {
        for (int s = 0; s < 6; ++s) {
            const float a = -TRAIL_W / 2 + float(s) * TRAIL_SW + rw_[i], b = a + TRAIL_SW;
            const float xs[4] = {rx_[i] + nx_[i] * a, rx_[i] + nx_[i] * b, rx_[i + 1] + nx_[i + 1] * b,
                                 rx_[i + 1] + nx_[i + 1] * a};
            const float ys[4] = {ry_[i] + ny_[i] * a, ry_[i] + ny_[i] * b, ry_[i + 1] + ny_[i + 1] * b,
                                 ry_[i + 1] + ny_[i + 1] * a};
            c.fillConvex(xs, ys, 4, kRainbow[s]);
        }
    }
}

void Game::drawMarker(Canvas& c, double dr) const {
    if (!hasMarker_ || mode_ == Mode::Title) return;
    const int sy = int(std::lround(FH - (marker_.wy - dr)));
    if (sy < -40 || sy > H + 30) return;

    const int offset = int(time_ * 20) % 7;
    for (int x = -offset; x < W; x += 7) c.hspan(sy, x, x + 3, kLine);

    const std::string label = "LAST CRASH";
    const int bw = textWidth(label, 1) + 6, bh = 11;
    const int lx = marker_.x > FW / 2 ? 6 : W - 6 - bw, ly = sy - bh - 3;
    panel(c, lx, ly, bw, bh);
    drawText(c, label, lx + 3, ly + 2, 1, kText);

    if (marker_.fade > 0) {
        const int gx = int(std::lround(marker_.x));
        const int gy = sy + int(std::lround(std::sin(time_ * 3) * 1.5 - (1 - marker_.fade) * 17));
        drawSprite(c, kGhost, kGhostPal, gx - 8, gy - 14, 0.6f * marker_.fade);
        drawSprite(c, kHalo, kHaloPal, gx - 4, gy - 18, 0.9f * marker_.fade);
    }
}

void Game::drawBunny(Canvas& c) const {
    if (mode_ == Mode::Dead) return;
    const bool blink = mode_ == Mode::Playing && grace_ > 0 && int(std::floor(time_ * 16)) % 2 == 0;
    const float alpha = blink ? 0.45f : 1.0f;
    const int bob = mode_ == Mode::Title ? int(std::lround(std::sin(time_ * 3) * 3)) : int(std::lround(std::sin(time_ * 11)));
    const int x = int(std::lround(bx_)) - 8, y = int(std::lround(by_)) - 14 + bob;
    const bool wingsUp = int(std::floor(time_ * (mode_ == Mode::Title ? 4 : 10))) % 2 == 0;
    const int wingY = y + (wingsUp ? 13 : 17);
    drawSprite(c, wingsUp ? kWingUpL : kWingDownL, kBunnyPal, x - 6, wingY, alpha);
    drawSprite(c, wingsUp ? kWingUpR : kWingDownR, kBunnyPal, x + 15, wingY, alpha);
    drawSprite(c, kBunny, kBunnyPal, x, y, alpha);
}

void Game::drawHud(Canvas& c) const {
    if (mode_ == Mode::Title) return;

    const std::string num = std::to_string(screens_);
    const int lw = textWidth("SCREENS", 1), nw = textWidth(num, 3);
    const int bw = std::max(lw, nw) + 10, bh = 38;
    const int x = W - 5 - bw, y = 5;
    panel(c, x, y, bw, bh);
    drawText(c, "SCREENS", x + bw - 5 - lw, y + 5, 1, kMuted);
    drawTextShadow(c, num, x + bw - 5 - nw, y + 14, 3, popT_ > 0 ? kSun : kText, kHot);

    if (best_ > 0) {
        const std::string label = "BEST ", value = std::to_string(best_);
        panel(c, 5, 5, textWidth(label + value, 1) + 8, 13);
        drawText(c, label, 9, 8, 1, kMuted);
        drawText(c, value, 9 + int(label.size()) * 6, 8, 1, kSun);
    }

    if (mode_ == Mode::Playing && !holding_ && blinkOn(time_)) {
        const std::string hint = "HOLD TO STEER";
        const int w = textWidth(hint, 1) + 10, hx = (W - w) / 2, hy = H - 22;
        panel(c, hx, hy, w, 14);
        drawText(c, hint, hx + 5, hy + 4, 1, kSun);
    }

    if (toastT_ > 0) centeredShadow(c, toast_, 96 - int((1.6f - toastT_) * 10), 2, kSun, kInk);
}

void Game::drawTitle(Canvas& c) const {
    const std::string top = "RAINBOW", bottom = "BUNNY";
    int x = (W - textWidth(top, 3)) / 2;
    for (std::size_t i = 0; i < top.size(); ++i, x += 18) {
        const int dy = int(std::lround(std::sin(time_ * 4.5 - double(i) * 0.6) * 2));
        drawChar(c, top[i], x + 2, 42 + dy + 2, 3, kInk);
        drawChar(c, top[i], x, 42 + dy, 3, kLogo[i % 7]);
    }
    x = (W - textWidth(bottom, 4)) / 2;
    for (std::size_t i = 0; i < bottom.size(); ++i, x += 24) {
        const int dy = int(std::lround(std::sin(time_ * 4.5 - double(i + 7) * 0.6) * 2));
        drawChar(c, bottom[i], x + 2, 72 + dy + 2, 4, kHot);
        drawChar(c, bottom[i], x, 72 + dy, 4, kText);
    }

    static const char* const lines[] = {"PRESS AND HOLD THE LEFT", "MOUSE BUTTON TO FLY.", "THE BUNNY FOLLOWS YOUR",
                                        "CURSOR WHILE YOU HOLD.", "DON'T TOUCH THE WALLS!"};
    panel(c, 22, 128, W - 44, 62);
    int ly = 135;
    for (const char* line : lines) {
        const std::string s(line);
        centered(c, s, ly, 1, s.rfind("DON'T", 0) == 0 ? kSun : kMuted);
        ly += 10;
    }

    if (blinkOn(time_)) {
        const std::string cta = "PRESS & HOLD";
        const int w = textWidth(cta, 2) + 14, px = (W - w) / 2;
        panel(c, px, 306, w, 24);
        drawText(c, cta, px + 7, 311, 2, kSun);
    }
    if (best_ > 0) centeredShadow(c, "BEST " + std::to_string(best_) + " SCREENS", 338, 1, kMuted, kInk);
}

void Game::drawGameOver(Canvas& c) const {
    if (deadT_ < OVER_DELAY) return;
    centeredShadow(c, "BONK!", 48, 5, kHot, kInk);
    panel(c, 26, 104, W - 52, 104);
    centered(c, "YOU FLEW PAST", 114, 1, kMuted);
    centeredShadow(c, std::to_string(screens_), 128, 5, kText, kHot);
    centered(c, "SCREENS", 170, 1, kMuted);
    if (newBest_ && screens_ > 0) {
        if (blinkOn(time_)) centered(c, "NEW BEST!", 186, 2, kSun);
    } else {
        centered(c, "BEST " + std::to_string(best_), 188, 1, kMuted);
    }
    if (deadT_ > RETRY_DELAY && blinkOn(time_)) {
        const std::string retry = "HOLD TO RETRY";
        const int w = textWidth(retry, 2) + 14, px = (W - w) / 2;
        panel(c, px, 306, w, 24);
        drawText(c, retry, px + 7, 311, 2, kSun);
    }
}
