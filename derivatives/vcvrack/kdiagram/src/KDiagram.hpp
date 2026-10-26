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
        SIM_RATE_PARAM,
        RESET_PARAM,
        PAUSE_PARAM,
        SPEED_CURSOR1_PARAM,
        SPEED_CURSOR2_PARAM,
        SPEED_CURSOR3_PARAM,
        CHANNEL_BASE_PARAM,
        CURSOR_SELECT_PARAM,
        SCALE_PARAM,
        ROT_CCW_PARAM,
        ROT_CW_PARAM,
        NOTE_LENGTH_PARAM,
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
    float pitchV[3] = {}, lastSpeed[3] = {-1, -1, -1}, lastReset = 0, lastL = 0, lastR = 0;
    float lastNoteLength = -1;
    int lastPause = -1, lastChannel = -1, lastCursor = -1, lastScaleIdx = -1;
    /** Model note-ons/offs; a cursor's gate is high while any of its notes sound. */
    worldofcake::bridge::NoteOutputScheduler notes;
    worldofcake::rack::RetriggerGate gates[3];
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
