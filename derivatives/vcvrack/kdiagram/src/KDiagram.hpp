#pragma once
#include <rack.hpp>
#include <dsp/digital.hpp>
#include <atomic>
#include <memory>
#include <KDiagramControlRunner.h>
#include <NoteOutputScheduler.h>
#include <WocRackVoltage.hpp>
using namespace rack;
struct KDiagram : Module
{
    enum ParamIds
    {
        RESERVED_DISPLAY_RATE_PARAM, // Legacy slot; never reuse in saved Rack patches.
        RESET_PARAM,
        PAUSE_PARAM,
        SPEED_CURSOR1_PARAM,
        SPEED_CURSOR2_PARAM,
        SPEED_CURSOR3_PARAM,
        RESERVED_MIDI_CHANNEL_PARAM, // Routing is model state, not a Rack panel control.
        CURSOR_SELECT_PARAM,
        SCALE_PARAM,
        ROT_CCW_PARAM,
        ROT_CW_PARAM,
        NOTE_LENGTH_PARAM,
        TERMINUS_PARAM,
        NUM_PARAMS
    };
    enum InputIds
    {
        NUM_INPUTS
    };
    enum OutputIds
    {
        GATE1_OUTPUT,
        CVY1_OUTPUT,
        CVX1_OUTPUT,
        CVHY1_OUTPUT,
        GATE2_OUTPUT,
        CVY2_OUTPUT,
        CVX2_OUTPUT,
        CVHY2_OUTPUT,
        GATE3_OUTPUT,
        CVY3_OUTPUT,
        CVX3_OUTPUT,
        CVHY3_OUTPUT,
        NUM_OUTPUTS
    };
    enum LightIds
    {
        NUM_LIGHTS
    };
    std::unique_ptr<worldofcake::bridge::KDiagramControlRunner> runner;
    std::atomic<std::uint64_t> guiSequence{1};
    std::uint64_t reportedPersistenceTimeouts = 0;
    std::uint64_t hostSequence = 1;
    static constexpr std::size_t kCursorCount = std::tuple_size<decltype(worldofcake::bridge::KDiagramVisualSnapshot::cursors)>::value;
    std::array<float, kCursorCount> pitchV{};
    std::array<float, kCursorCount> lastSpeed = [] { std::array<float, kCursorCount> values{}; values.fill(-1.f); return values; }();
    float lastReset = 0, lastL = 0, lastR = 0;
    float lastNoteLength = -1;
    int lastTerminus = -1;
    int lastPause = -1, lastCursor = -1, lastScaleIdx = -1;
    int baseMidiChannel = 1; // Internal event routing, restored from the Haxe snapshot.
    /** Model note-ons/offs; a cursor's gate is high while any of its notes sound. */
    worldofcake::bridge::NoteOutputScheduler notes;
    worldofcake::rack::RetriggerGate gates[kCursorCount];
    KDiagram();
    ~KDiagram() override;
    json_t* dataToJson() override;
    void dataFromJson(json_t*) override;
    void process(const ProcessArgs&) override;
    void click(float, float);
    void send(int, double);
};
struct KDiagramWidget : ModuleWidget
{
    explicit KDiagramWidget(KDiagram*);
};
