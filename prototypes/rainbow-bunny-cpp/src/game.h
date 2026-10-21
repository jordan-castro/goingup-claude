// Rainbow Bunny game logic and drawing. Knows nothing about windows or input devices:
// the platform layer feeds it pointer events and elapsed time, then shows the Canvas.
#pragma once

#include <deque>
#include <filesystem>
#include <random>
#include <string>
#include <vector>

#include "gfx.h"

class Game {
public:
    static constexpr int W = 200;  // play field size in pixels; the window scales it up
    static constexpr int H = 360;

    enum class Mode { Title, Playing, Dead };

    Game(std::filesystem::path savePath, unsigned seed);

    // Pointer position is in play-field pixels. `touch` lifts the steering point above the finger.
    void pointerDown(float x, float y, bool touch);
    void pointerMove(float x, float y);
    void pointerUp();

    void update(double dt);  // seconds since the last call
    void draw(Canvas& c);

    Mode mode() const { return mode_; }
    int screens() const { return screens_; }

private:
    struct Control { float w, c, g; };         // tunnel control point: world y, centre, gap
    struct WallSample { float w, l, r; int k; };
    struct TrailPoint { float wy, x; };
    struct Particle { float x, y, vx, vy, life, maxLife, size, drag, scroll; Color color; };
    struct Star { float x, y, z, phase; bool big; };
    struct Marker { float wy, x, fade; bool passed; };

    void tick(float h);
    void startGame();
    void die();
    void resetWorld();
    float difficulty() const;
    Control makeControl(const Control& prev);
    void ensureControls(std::size_t n);
    WallSample sampleWall(float w);
    void fillWalls();
    void wallAtWorld(float wy, float& l, float& r) const;
    bool hitsWall() const;
    void onNewScreen(int s);
    void burst(float x, float y, int count, const Color* colors, int colorCount, float minSpeed, float maxSpeed,
               float scroll);
    void showToast(std::string text);
    float tailWorldY() const;
    float rand(float a, float b);
    void load();
    void save() const;

    void drawWalls(Canvas& c, double dr) const;
    void drawTrail(Canvas& c, double dr);
    void drawMarker(Canvas& c, double dr) const;
    void drawBunny(Canvas& c) const;
    void drawHud(Canvas& c) const;
    void drawTitle(Canvas& c) const;
    void drawGameOver(Canvas& c) const;

    std::filesystem::path savePath_;
    std::mt19937 rng_;

    Mode mode_ = Mode::Title;
    double time_ = 0, runT_ = 0, D_ = 0;  // D_ = distance flown, in world pixels
    float speed_ = 55;
    int screens_ = 0, best_ = 0;
    bool newBest_ = false;

    float bx_, by_, tx_, ty_;
    bool holding_ = false;
    float touchOffset_ = 0;
    float grace_ = 0, deadT_ = 0, shake_ = 0, popT_ = 0;

    std::vector<Control> controls_;
    std::size_t ctrlIdx_ = 0;
    std::deque<WallSample> walls_;
    int sampleK_ = 0;
    float nextW_ = 0, wobble_ = 0;

    std::deque<TrailPoint> trail_;
    std::vector<Particle> particles_;
    std::vector<Star> stars_;

    bool hasCrash_ = false;
    float crashWy_ = 0, crashX_ = 0;
    bool hasMarker_ = false;
    Marker marker_{};

    std::string toast_;
    float toastT_ = 0;

    std::vector<float> rawX_, rx_, ry_, rw_, nx_, ny_;  // scratch buffers for the trail ribbon
};
