#pragma once
#include <rack.hpp>
#include <atomic>
#include <memory>
#include <array>
#include <GoldenpondControlRunner.h>
#include <NoteOutputScheduler.h>
#include <WocRackVoltage.hpp>
#include <string>
using namespace rack;
struct Goldenpond;
struct GoldenpondTextField : rack::ui::TextField {
    Goldenpond* module = nullptr;
    int controlId = 0;
    int textIndex = 0;
    void onSelectKey(const SelectKeyEvent& e) override;
    void onDeselect(const DeselectEvent& e) override;
};
struct GoldenpondPianoRoll : rack::widget::OpaqueWidget {
    Goldenpond* module = nullptr;
    void draw(const DrawArgs& args) override;
};
struct Goldenpond : Module {
    enum ParamIds {
        RESET_PARAM, PAUSE_PARAM, MUTE_PARAM,
        OCTAVE0_PARAM, VELOCITY0_PARAM, OCTAVE1_PARAM, VELOCITY1_PARAM,
        OCTAVE2_PARAM, VELOCITY2_PARAM, OCTAVE3_PARAM, VELOCITY3_PARAM,
        BPM_PARAM, CHORD_DURATION_PARAM, ZOOM_PARAM, CORRECTION_TARGET_PARAM,
        KEY_PARAM, MODE_PARAM, NUM_PARAMS
    };
    enum InputIds { CORRECT1_INPUT, CORRECT2_INPUT, CORRECT3_INPUT, NUM_INPUTS };
    enum OutputIds { GATE1_OUTPUT, PITCH1_OUTPUT, GATE2_OUTPUT, PITCH2_OUTPUT, GATE3_OUTPUT, PITCH3_OUTPUT, GATE4_OUTPUT, PITCH4_OUTPUT,
                     CORRECT1_OUTPUT, CORRECT2_OUTPUT, CORRECT3_OUTPUT, NUM_OUTPUTS };
    enum LightIds { NUM_LIGHTS };
    std::unique_ptr<worldofcake::bridge::GoldenpondControlRunner> runner;
    float pitch[4] = {};
    float correctedPitch[3] = {};
    int lastPause = -1;
    int lastMute = -1;
    float lastReset = 0.f;
    float lastValues[14] = {};
    std::uint64_t sequence = 1;
    std::array<std::string, 5> textValues;
    std::array<int, 3> previousCorrectionInput{};
    std::array<bool, 3> correctionInputValid{};
    std::array<bool, 3> correctionDirectionValid{};
    std::array<bool, 3> correctionDescending{};
    Goldenpond(); ~Goldenpond() override;
    void process(const ProcessArgs&) override;
    json_t* dataToJson() override; void dataFromJson(json_t*) override;
    void send(int, double);
    void sendText(int, const std::string&);
    void registerTextField(int index, GoldenpondTextField* field);
    void restoreTextFields();
    GoldenpondTextField* textFields[5] = {};
    /** Model note-ons/offs on the Rack clock; a part's gate is high while its notes sound. */
    worldofcake::bridge::NoteOutputScheduler notes;
    worldofcake::rack::RetriggerGate gates[4];
    /** An event mapping further than this from now means the model clock jumped. */
    static constexpr double kMaxEventSkewSeconds = 0.25;
    double audioTime = 0.0;
    double eventTimeOrigin = 0.0;
    double transportTime = 0.0;
    std::uint64_t transportEpoch = 0;
    std::uint64_t stagedEvents = 0;
    std::uint64_t consumedNoteOns = 0;
    std::uint64_t consumedNoteOffs = 0;
    double diagnosticsTime = 0.0;
    /** Once a second the audio thread publishes counters here; the widget logs them
        from the UI thread, because logging does file I/O. */
    std::atomic<std::uint64_t> diagStaged{0}, diagDropped{0}, diagNoteOns{0}, diagNoteOffs{0}, diagPending{0};
    std::atomic<bool> diagnosticsReady{false};
    void logDiagnostics();
};
struct GoldenpondWidget : ModuleWidget {
    explicit GoldenpondWidget(Goldenpond*);
    void step() override;
};
