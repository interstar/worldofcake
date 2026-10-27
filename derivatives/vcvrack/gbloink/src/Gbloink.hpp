#pragma once
#include <atomic>
#include <memory>
#include <rack.hpp>
#include <dsp/digital.hpp>

#include <GbloinkControlRunner.h>
#include <NoteOutputScheduler.h>
#include <WocRackVoltage.hpp>

using namespace rack;

struct Gbloink : Module
{
    enum ParamIds
    {
        SPEED_BALL1_PARAM,
        SPEED_BALL2_PARAM,
        SPEED_BALL3_PARAM,
        /** Snap 0…5 → chromatic, major, minor, harmonic_minor, melodic_minor, minor_blues. */
        SCALE_PARAM,
        /** 0 = slow physics (long period), 1 = fast (short period). */
        /** Momentary: `ISequencer.reset()` — wipe blocks, pending events, restore balls & time. */
        RESET_PARAM,
        /** Latch 0 = run, 1 = pause; presents the model flag (`setPaused`). */
        PAUSE_PARAM,
        MUTE_PARAM,
        /** Latch: play note on play-area edge bounce (off = walls silent, default). */
        EDGE_NOTES_PARAM,
        /** Seconds from each note-on to its note-off (model-owned; normalized 0..1). */
        NOTE_LENGTH_PARAM,
        /** MIDI velocity 1..127 of each ball's notes (appended so saved patches keep their parameter ids). */
        VELOCITY_BALL1_PARAM,
        VELOCITY_BALL2_PARAM,
        VELOCITY_BALL3_PARAM,
        NUM_PARAMS
    };
    enum InputIds
    {
        NUM_INPUTS
    };
    enum OutputIds
    {
        GATE_BALL1_OUTPUT,
        PITCH_BALL1_OUTPUT,
        VELOCITY_BALL1_OUTPUT,
        GATE_BALL2_OUTPUT,
        PITCH_BALL2_OUTPUT,
        VELOCITY_BALL2_OUTPUT,
        GATE_BALL3_OUTPUT,
        PITCH_BALL3_OUTPUT,
        VELOCITY_BALL3_OUTPUT,
        NUM_OUTPUTS
    };
    enum LightIds
    {
        NUM_LIGHTS
    };

    std::unique_ptr<worldofcake::bridge::GbloinkControlRunner> runner;
    float pitchV[3] = {0.f, 0.f, 0.f};
    /** Held at the velocity of each ball's latest note-on, like the pitch CV. */
    float velocityV[3] = {0.f, 0.f, 0.f};
    float lastSpeed[3] = {-1.f, -1.f, -1.f};
    float lastVelocity[3] = {-1.f, -1.f, -1.f};
    float lastNoteLength = -1.f;
    int lastScaleIdx = -1;
    int lastPause = -1;
    int lastMute = -1;
    /** -1 = not yet synced to Haxe; 0/1 = last pushed wall-note latch. */
    int lastEdgeNotes = -1;
    float lastResetButton = 0.f;
    bool ignoreResetUntilReleased = false;
    std::atomic<std::uint64_t> guiSequence{1};
    std::uint64_t hostSequence = 1;
    std::atomic<std::uint64_t> autosaveCalls{0};
    /** Model note-ons/offs; a ball's gate is high while any of its notes sound. */
    worldofcake::bridge::NoteOutputScheduler notes;
    worldofcake::rack::RetriggerGate gates[3];

    Gbloink();
    ~Gbloink() override;
    void process(const ProcessArgs& args) override;
    json_t* dataToJson() override;
    void dataFromJson(json_t* rootJ) override;

    void playAreaClick(float localX, float localY);

  private:
    void syncPanelToRunner();
    void enqueueHostValue(int controlId, double value);
};

struct GbloinkTrailSettings;
struct GbloinkWidget : ModuleWidget
{
    std::shared_ptr<GbloinkTrailSettings> trailSettings;
    explicit GbloinkWidget(Gbloink* module);
    void appendContextMenu(ui::Menu* menu) override;
};
