#pragma once
#include <rack.hpp>
#include <WorldOfCakeBridgeTypes.h>
#include <memory>

/** Editor-only appearance settings; deliberately outside the musical model/audio path. */
struct GbloinkTrailSettings {
    bool enabled = true;
    bool halfResolution = true;
    bool diagnostics = false;
    bool collisionRipples = true;
    bool blockFlashes = true;
    float halfLife = 0.22f;
};

struct GbloinkTrailWidget : rack::widget::OpenGlWidget {
    const worldofcake::bridge::GbloinkVisualSnapshot* snapshot = nullptr;
    explicit GbloinkTrailWidget(std::shared_ptr<GbloinkTrailSettings> settings);
    ~GbloinkTrailWidget() override;
    void drawFramebuffer() override;
    void onContextCreate(const ContextCreateEvent& e) override;
    void onContextDestroy(const ContextDestroyEvent& e) override;
    bool failed() const;
private:
    struct Impl;
    std::unique_ptr<Impl> impl;
};
