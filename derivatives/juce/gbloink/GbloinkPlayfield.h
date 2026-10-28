#pragma once
#include "WorldOfCakeBridgeTypes.h"
#include <juce_opengl/juce_opengl.h>
#include <mutex>

// Editor-owned presentation. Neither GL nor paint accesses the model/audio thread.
class GbloinkPlayfield final : public juce::Component, private juce::OpenGLRenderer {
public:
    GbloinkPlayfield();
    ~GbloinkPlayfield() override;
    void update(const worldofcake::bridge::GbloinkVisualSnapshot&);
    void paint(juce::Graphics&) override;
    void setEffectsEnabled(bool);
private:
    void newOpenGLContextCreated() override;
    void renderOpenGL() override;
    void openGLContextClosing() override;
    void clearHistory();
    void drawQuad();
    struct Impact { worldofcake::bridge::GbloinkCollisionCue cue; double born; };
    worldofcake::bridge::GbloinkVisualSnapshot snapshot;
    std::vector<Impact> impacts;
    int lastSerial = 0, epoch = -1;
    std::uint64_t revision = 0;
    double previousModelTime = 0;
    bool effectsEnabled = true;
    // Only this small render packet crosses from the message thread to GL.
    std::mutex packetMutex;
    struct Packet {
        std::array<worldofcake::bridge::BallSnapshot, 3> balls{};
        std::uint64_t reset = 0;
        double modelTime = 0;
        bool moving = false, trails = true;
    } packet;
    juce::OpenGLContext context;
    std::unique_ptr<juce::OpenGLShaderProgram> shader;
    juce::OpenGLFrameBuffer history[2];
    GLuint vertices = 0;
    int position = -1, current = 0, textureWidth = 0;
    std::uint64_t renderedReset = 0;
    double renderedModelTime = -1;
    double lastFrameTime = 0;
    std::atomic<bool> gpuReady{false};
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GbloinkPlayfield)
};
