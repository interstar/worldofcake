#include "Goldenpond.hpp"
#include "plugin.hpp"
#include <WocRackStateJson.hpp>
#include <WocRackTiming.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/goldenpond/GoldenpondRackLayoutGenerated.h>
#include <worldofcake/generated/goldenpond/GoldenpondControlMetadataGenerated.h>
#include <asset.hpp>
#include <componentlibrary.hpp>
#include <helpers.hpp>
#include <cmath>
#include <cstring>
#include <algorithm>
using namespace rack::app;
using namespace rack::widget;
namespace GoldenpondLayout = worldofcake::rack::goldenpond;
namespace {
const int chordDurations[] = {1, 2, 3, 4, 6, 8, 12, 16};
const char* defaultTextValues[] = {
    worldofcake::metadata::goldenpond::kChordinput.defaultText,
    worldofcake::metadata::goldenpond::kRhythm0.defaultText,
    worldofcake::metadata::goldenpond::kRhythm1.defaultText,
    worldofcake::metadata::goldenpond::kRhythm2.defaultText,
    worldofcake::metadata::goldenpond::kRhythm3.defaultText};

NVGcolor partColor(int part) {
    static const int colors[] = {0x5cc8e8, 0x9acd4c, 0xe36d73, 0xb88ee0};
    const int c = colors[std::max(0, std::min(3, part))];
    return nvgRGB((c >> 16) & 255, (c >> 8) & 255, c & 255);
}
}
void GoldenpondTextField::onSelectKey(const SelectKeyEvent& e) {
    if (e.action == GLFW_PRESS && e.key == GLFW_KEY_ENTER && module != nullptr) {
        module->sendText(controlId, text);
    }
    TextField::onSelectKey(e);
}
void GoldenpondTextField::onDeselect(const DeselectEvent& e) {
    if (module != nullptr) module->sendText(controlId, text);
    TextField::onDeselect(e);
}
void GoldenpondPianoRoll::draw(const DrawArgs& args) {
    NVGcontext* vg = args.vg;
    nvgBeginPath(vg); nvgRect(vg, 0, 0, box.size.x, box.size.y);
    nvgFillColor(vg, nvgRGB(18, 20, 26)); nvgFill(vg);
    if (module == nullptr) return;
    const auto snapshot = module->runner->latestVisualSnapshot();
    int low = 127, high = 0;
    for (const auto& note : snapshot.notes) { low = std::min(low, note.pitch); high = std::max(high, note.pitch); }
    if (snapshot.notes.empty()) { low = 48; high = 84; }
    int center = (low + high) / 2;
    low = std::max(0, center - 18); high = std::min(127, low + 36);
    low = std::max(0, high - 36);
    const double range = std::max(1, high - low);
    const double loop = snapshot.loopLengthTicks > 0 ? snapshot.loopLengthTicks : 1.0;
    nvgSave(vg); nvgScissor(vg, 0, 0, box.size.x, box.size.y);
    for (const auto& note : snapshot.notes) {
        if (note.startTick >= loop) continue;
        const float x = static_cast<float>(note.startTick / loop * box.size.x);
        const float w = static_cast<float>(std::max(2.0, note.durationTicks / loop * box.size.x));
        const float y = static_cast<float>((high - note.pitch) / range * box.size.y);
        nvgBeginPath(vg); nvgRect(vg, x, y, w, std::max(2.0f, box.size.y / 40.0f));
        nvgFillColor(vg, partColor(note.partId)); nvgFill(vg);
    }
    const double position = std::fmod(std::max(0.0, snapshot.positionTicks), loop);
    nvgBeginPath(vg); nvgRect(vg, static_cast<float>(position / loop * box.size.x), 0, 0.8f, box.size.y);
    nvgFillColor(vg, nvgRGB(240, 240, 240)); nvgFill(vg);
    if (snapshot.compileError) {
        nvgBeginPath(vg); nvgRect(vg, 0.75f, 0.75f, box.size.x - 1.5f, box.size.y - 1.5f);
        nvgStrokeColor(vg, nvgRGBA(200, 82, 92, 190)); nvgStrokeWidth(vg, 1.5f); nvgStroke(vg);
    }
    nvgRestore(vg);
}
Goldenpond::Goldenpond() {
    config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
    configButton(RESET_PARAM, "Reset"); configSwitch(PAUSE_PARAM, 0.f, 1.f, 0.f, "Pause", {"Run", "Pause"}); configSwitch(MUTE_PARAM, 0.f, 1.f, 0.f, "Mute output", {"Output", "Muted"});
    for (int i = 0; i < 3; ++i) configInput(CORRECT1_INPUT + i, "Chord correction " + std::to_string(i + 1));
    for (int i = 0; i < 4; ++i) {
        const auto* octave = i == 0 ? &worldofcake::metadata::goldenpond::kOctave0 : i == 1 ? &worldofcake::metadata::goldenpond::kOctave1 : i == 2 ? &worldofcake::metadata::goldenpond::kOctave2 : &worldofcake::metadata::goldenpond::kOctave3;
        const auto* velocity = i == 0 ? &worldofcake::metadata::goldenpond::kVelocity0 : i == 1 ? &worldofcake::metadata::goldenpond::kVelocity1 : i == 2 ? &worldofcake::metadata::goldenpond::kVelocity2 : &worldofcake::metadata::goldenpond::kVelocity3;
        configParam(OCTAVE0_PARAM + i * 2, octave->minimum, octave->maximum, octave->defaultValue, "Part " + std::to_string(i + 1) + " octave");
        configParam(VELOCITY0_PARAM + i * 2, velocity->minimum, velocity->maximum, velocity->defaultValue, "Part " + std::to_string(i + 1) + " velocity");
        paramQuantities[OCTAVE0_PARAM + i * 2]->snapEnabled = true;
    }
    configParam(BPM_PARAM, worldofcake::metadata::goldenpond::kBpm.minimum, worldofcake::metadata::goldenpond::kBpm.maximum, worldofcake::metadata::goldenpond::kBpm.defaultValue, "BPM");
    configParam(CHORD_DURATION_PARAM, 0.f, 7.f, 3.f, "Chord duration");
    paramQuantities[CHORD_DURATION_PARAM]->snapEnabled = true;
    configParam(ZOOM_PARAM, worldofcake::metadata::goldenpond::kZoom.minimum, worldofcake::metadata::goldenpond::kZoom.maximum, worldofcake::metadata::goldenpond::kZoom.defaultValue, "Piano roll zoom");
    configSwitch(CORRECTION_TARGET_PARAM, 0.f, static_cast<float>(worldofcake::metadata::goldenpond::kCorrectiontarget.choiceCount - 1), static_cast<float>(worldofcake::metadata::goldenpond::kCorrectiontarget.defaultIndex), "Correction target",
                 {worldofcake::metadata::goldenpond::kCorrectiontargetChoices[0].label, worldofcake::metadata::goldenpond::kCorrectiontargetChoices[1].label, worldofcake::metadata::goldenpond::kCorrectiontargetChoices[2].label, worldofcake::metadata::goldenpond::kCorrectiontargetChoices[3].label});
    configParam(KEY_PARAM, worldofcake::metadata::goldenpond::kKeyselect.choices[0].value, worldofcake::metadata::goldenpond::kKeyselect.choices[worldofcake::metadata::goldenpond::kKeyselect.choiceCount - 1].value, worldofcake::metadata::goldenpond::kKeyselect.choices[worldofcake::metadata::goldenpond::kKeyselect.defaultIndex].value, "Initial key");
    paramQuantities[KEY_PARAM]->snapEnabled = true;
    configParam(MODE_PARAM, worldofcake::metadata::goldenpond::kModeselect.choices[0].value, worldofcake::metadata::goldenpond::kModeselect.choices[worldofcake::metadata::goldenpond::kModeselect.choiceCount - 1].value, worldofcake::metadata::goldenpond::kModeselect.choices[worldofcake::metadata::goldenpond::kModeselect.defaultIndex].value, "Initial scale");
    paramQuantities[MODE_PARAM]->snapEnabled = true;
    const char* labels[] = {"Part 1 Gate","Part 1 Pitch","Part 2 Gate","Part 2 Pitch","Part 3 Gate","Part 3 Pitch","Part 4 Gate","Part 4 Pitch"};
    for (int i = 0; i < 8; ++i) configOutput(i, labels[i]);
    configOutput(CORRECT1_OUTPUT, "Corrected pitch 1");
    configOutput(CORRECT2_OUTPUT, "Corrected pitch 2");
    configOutput(CORRECT3_OUTPUT, "Corrected pitch 3");
    for (int i = 0; i < 5; ++i) textValues[i] = defaultTextValues[i];
    runner.reset(new worldofcake::bridge::GoldenpondControlRunner());
    runner->start(worldofcake::rack::kControlPeriodSeconds);
}
Goldenpond::~Goldenpond() { if (runner) runner->stop(); }
void Goldenpond::send(int id, double value) { worldofcake::bridge::ControlCommand c; c.kind = worldofcake::bridge::CommandKind::setValue; c.sequence = sequence++; c.controlId = id; c.value = value; runner->enqueueHostCommand(c); }
void Goldenpond::sendText(int id, const std::string& value) {
    const int textIndex = id == worldofcake::control::goldenpond::kChordinput ? 0
                        : id == worldofcake::control::goldenpond::kRhythm0 ? 1
                        : id == worldofcake::control::goldenpond::kRhythm1 ? 2
                        : id == worldofcake::control::goldenpond::kRhythm2 ? 3
                        : id == worldofcake::control::goldenpond::kRhythm3 ? 4 : -1;
    if (textIndex >= 0) textValues[static_cast<std::size_t>(textIndex)] = value;
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::textSubmitted;
    c.sequence = sequence++;
    c.controlId = id;
    std::strncpy(c.text, value.c_str(), sizeof(c.text) - 1);
    c.text[sizeof(c.text) - 1] = '\0';
    runner->enqueueGuiCommand(c);
}
void Goldenpond::process(const ProcessArgs& a) {
    // The model releases sounding notes on pause, mute, and reset; nothing to flush here.
    const auto enqueueLifecycle = [this](const worldofcake::bridge::ControlCommand& c) {
        if (c.kind == worldofcake::bridge::CommandKind::reset) {
            transportTime = 0.0;
            ++transportEpoch;
        }
        runner->enqueueHostCommand(c);
    };
    worldofcake::rack::syncTransport(params[PAUSE_PARAM].getValue(), lastPause, params[RESET_PARAM].getValue(), lastReset,
                                     enqueueLifecycle);
    worldofcake::rack::syncLifecycleLatch(params[MUTE_PARAM].getValue(), lastMute, worldofcake::bridge::muteCommand,
                                          enqueueLifecycle);
    worldofcake::bridge::PreparedEvent e;
    while (runner->popPreparedEvent(e)) {
        // The runner releases events when model time reaches them, so each one
        // arrives within a control tick of being due. When an event maps far
        // from now, the model clock jumped (first event after load, reset, state
        // import): re-anchor so the model timeline continues from this moment.
        if (std::fabs(e.timestamp + eventTimeOrigin - audioTime) > kMaxEventSkewSeconds)
            eventTimeOrigin = audioTime - e.timestamp;
        notes.schedule(e.timestamp + eventTimeOrigin, e);
        ++stagedEvents;
    }
    const double blockEnd = audioTime + a.sampleTime;
    notes.emitDue(blockEnd, [this](double, const worldofcake::bridge::PreparedEvent& ev) {
        using worldofcake::bridge::NoteOutputScheduler;
        if (ev.type == NoteOutputScheduler::kNoteOn) {
            if (ev.channel >= 0 && ev.channel < 4)
                pitch[ev.channel] = worldofcake::rack::midiNoteToOneVoltPerOctave(ev.data2);
            ++consumedNoteOns;
        } else if (ev.type == NoteOutputScheduler::kNoteOff) {
            ++consumedNoteOffs;
        }
    });
    for (int i = 0; i < 3; ++i) {
        if (!inputs[CORRECT1_INPUT + i].isConnected()) {
            correctedPitch[i] = 0.f;
            correctionInputValid[i] = false;
            correctionDirectionValid[i] = false;
            continue;
        }
        const int incoming = std::max(0, std::min(127, static_cast<int>(std::round(inputs[CORRECT1_INPUT + i].getVoltage() * 12.f + 60.f))));
        int column = 0;
        if (!correctionInputValid[i]) {
            previousCorrectionInput[i] = incoming;
            correctionInputValid[i] = true;
        } else if (incoming != previousCorrectionInput[i]) {
            correctionDescending[i] = incoming < previousCorrectionInput[i];
            correctionDirectionValid[i] = true;
            previousCorrectionInput[i] = incoming;
        }
        if (correctionDirectionValid[i]) column = correctionDescending[i] ? 2 : 1;
        correctedPitch[i] = worldofcake::rack::midiNoteToOneVoltPerOctave(runner->correctedNote(incoming, column));
    }
    const int ids[] = {worldofcake::control::goldenpond::kOctave0, worldofcake::control::goldenpond::kVelocity0,
                       worldofcake::control::goldenpond::kOctave1, worldofcake::control::goldenpond::kVelocity1,
                       worldofcake::control::goldenpond::kOctave2, worldofcake::control::goldenpond::kVelocity2,
                       worldofcake::control::goldenpond::kOctave3, worldofcake::control::goldenpond::kVelocity3,
                       worldofcake::control::goldenpond::kBpm, worldofcake::control::goldenpond::kChordduration,
                       worldofcake::control::goldenpond::kZoom,
                       worldofcake::control::goldenpond::kCorrectiontarget,
                       worldofcake::control::goldenpond::kKeyselect,
                       worldofcake::control::goldenpond::kModeselect};
    const int paramIds[] = {OCTAVE0_PARAM, VELOCITY0_PARAM, OCTAVE1_PARAM, VELOCITY1_PARAM,
                          OCTAVE2_PARAM, VELOCITY2_PARAM, OCTAVE3_PARAM, VELOCITY3_PARAM,
                          BPM_PARAM, CHORD_DURATION_PARAM, ZOOM_PARAM, CORRECTION_TARGET_PARAM,
                          KEY_PARAM, MODE_PARAM};
    for (int i = 0; i < 14; ++i) {
        float value = params[paramIds[i]].getValue();
        if (paramIds[i] == CHORD_DURATION_PARAM) {
            const int index = std::max(0, std::min(7, static_cast<int>(std::round(value))));
            value = static_cast<float>(chordDurations[index]);
        }
        if (paramIds[i] == CORRECTION_TARGET_PARAM)
            value = static_cast<float>(std::max(0, std::min(3, static_cast<int>(std::round(value)))));
        if (paramIds[i] == KEY_PARAM)
            value = static_cast<float>(std::max(0, std::min(11, static_cast<int>(std::round(value)))));
        if (paramIds[i] == MODE_PARAM)
            value = static_cast<float>(std::max(0, std::min(6, static_cast<int>(std::round(value)))));
        if (std::fabs(value - lastValues[i]) > 0.0001f) {
            send(ids[i], value);
            lastValues[i] = value;
        }
    }
    for (int i = 0; i < 4; ++i) {
        const bool gate = gates[i].process(notes.soundingNotes(i), notes.noteOnCount(i), a.sampleTime);
        outputs[GATE1_OUTPUT + i * 2].setVoltage(gate ? 10.f : 0.f);
        outputs[PITCH1_OUTPUT + i * 2].setVoltage(pitch[i]);
    }
    // Corrected input pitch is not a model event, so it honours the model's mute here.
    const bool muted = runner->isModelMuted();
    for (int i = 0; i < 3; ++i) outputs[CORRECT1_OUTPUT + i].setVoltage(muted ? 0.f : correctedPitch[i]);
    // Rack has no universal musical transport clock.  Goldenpond therefore
    // runs from the runner's ordinary audio-time callback by default.  Keep
    // these transport accumulators for the future external-clock adapter, but
    // do not publish them here: publishing a host clock switches the runner
    // into DAW-style resynchronization mode and is not appropriate for a
    // free-running Rack module.
    if (!runner->isModelPaused()) transportTime += a.sampleTime;
    audioTime = blockEnd;
    diagnosticsTime += a.sampleTime;
    if (diagnosticsTime >= 1.0) {
        diagStaged.store(stagedEvents, std::memory_order_relaxed);
        diagDropped.store(notes.droppedEvents(), std::memory_order_relaxed);
        diagNoteOns.store(consumedNoteOns, std::memory_order_relaxed);
        diagNoteOffs.store(consumedNoteOffs, std::memory_order_relaxed);
        diagPending.store(notes.pendingCount(), std::memory_order_relaxed);
        diagnosticsReady.store(true, std::memory_order_release);
        diagnosticsTime = 0.0;
    }
}
void Goldenpond::logDiagnostics() {
    if (!diagnosticsReady.exchange(false, std::memory_order_acquire)) return;
    INFO("WorldOfCake Goldenpond events: produced=%llu popped=%llu bridgeDrops=%llu staged=%llu stagedDrops=%llu noteOn=%llu noteOff=%llu pending=%llu",
         static_cast<unsigned long long>(runner->producedEvents()),
         static_cast<unsigned long long>(runner->poppedEvents()),
         static_cast<unsigned long long>(runner->droppedEvents()),
         static_cast<unsigned long long>(diagStaged.load(std::memory_order_relaxed)),
         static_cast<unsigned long long>(diagDropped.load(std::memory_order_relaxed)),
         static_cast<unsigned long long>(diagNoteOns.load(std::memory_order_relaxed)),
         static_cast<unsigned long long>(diagNoteOffs.load(std::memory_order_relaxed)),
         static_cast<unsigned long long>(diagPending.load(std::memory_order_relaxed)));
}
json_t* Goldenpond::dataToJson() {
    json_t* root = worldofcake::rack::makeStateJson(runner->exportStateJson());
    for (int i = 0; i < 5; ++i) {
        const std::string key = "text" + std::to_string(i);
        json_object_set_new(root, key.c_str(), json_string(textValues[i].c_str()));
    }
    return root;
}
void Goldenpond::dataFromJson(json_t* j) {
    auto s = worldofcake::rack::readStateJson(j);
    if (!s.empty()) runner->importStateJson(s);
    bool hasSavedText = false;
    bool savedText[5] = {};
    for (int i = 0; i < 5; ++i) {
        const std::string key = "text" + std::to_string(i);
        json_t* value = j == nullptr ? nullptr : json_object_get(j, key.c_str());
        if (value && json_is_string(value)) {
            const char* text = json_string_value(value);
            textValues[i] = text == nullptr ? "" : text;
            savedText[i] = true;
            hasSavedText = true;
        }
    }
    if (!hasSavedText && !s.empty()) {
        const auto snapshot = runner->latestVisualSnapshot();
        textValues[0] = snapshot.chordInput;
        for (int i = 0; i < 4; ++i) textValues[i + 1] = snapshot.rhythmInputs[i];
    }
    if (hasSavedText) {
        const int ids[] = {worldofcake::control::goldenpond::kChordinput,
                           worldofcake::control::goldenpond::kRhythm0,
                           worldofcake::control::goldenpond::kRhythm1,
                           worldofcake::control::goldenpond::kRhythm2,
                           worldofcake::control::goldenpond::kRhythm3};
        for (int i = 0; i < 5; ++i)
            if (savedText[i]) sendText(ids[i], textValues[i]);
    }
    params[RESET_PARAM].setValue(0.f);
    lastReset = 0.f;
    if (!s.empty()) {
        const auto snapshot = runner->latestVisualSnapshot();
        params[PAUSE_PARAM].setValue(snapshot.paused ? 1.f : 0.f);
        lastPause = snapshot.paused ? 1 : 0;
        params[MUTE_PARAM].setValue(snapshot.muted ? 1.f : 0.f);
        lastMute = snapshot.muted ? 1 : 0;
    }
    restoreTextFields();
}
void Goldenpond::registerTextField(int index, GoldenpondTextField* field) {
    if (index >= 0 && index < 5) { textFields[index] = field; restoreTextFields(); }
}
void Goldenpond::restoreTextFields() {
    for (int i = 0; i < 5; ++i)
        if (textFields[i]) textFields[i]->setText(textValues[i]);
}
void GoldenpondWidget::step() {
    ModuleWidget::step();
    if (auto* m = dynamic_cast<Goldenpond*>(module)) m->logDiagnostics();
}
GoldenpondWidget::GoldenpondWidget(Goldenpond* m) {
    setModule(m); setPanel(createPanel(asset::plugin(pluginInstance, "generated/Goldenpond.svg")));
    addChild(createWidget<ScrewSilver>(mm2px(math::Vec(3, 0)))); addChild(createWidget<ScrewSilver>(mm2px(math::Vec(GoldenpondLayout::kPanelWidth - 3, 0))));
    addChild(createWidget<ScrewSilver>(mm2px(math::Vec(3, 125.5)))); addChild(createWidget<ScrewSilver>(mm2px(math::Vec(GoldenpondLayout::kPanelWidth - 3, 125.5))));
    const int textIds[] = {worldofcake::control::goldenpond::kChordinput,
                           worldofcake::control::goldenpond::kRhythm0,
                           worldofcake::control::goldenpond::kRhythm1,
                           worldofcake::control::goldenpond::kRhythm2,
                           worldofcake::control::goldenpond::kRhythm3};
    const auto play = GoldenpondLayout::kPlayarea;
    auto* roll = createWidget<GoldenpondPianoRoll>(mm2px(math::Vec(play.x, play.y)));
    roll->box.size = mm2px(math::Vec(play.width, play.height));
    roll->module = m;
    addChild(roll);
    for (int i = 0; i < 5; ++i) {
        const auto center = i == 0 ? GoldenpondLayout::kChordinputCenter
                                   : (i == 1 ? GoldenpondLayout::kRhythm0Center
                                              : (i == 2 ? GoldenpondLayout::kRhythm1Center
                                                         : (i == 3 ? GoldenpondLayout::kRhythm2Center : GoldenpondLayout::kRhythm3Center)));
        const math::Vec size = mm2px(math::Vec(i == 0 ? 97.84 : (97.84 / 3.0), 10));
        auto* field = createWidget<GoldenpondTextField>(mm2px(math::Vec(center.x, center.y)).minus(size.div(2)));
        field->box.size = size;
        field->module = m;
        field->controlId = textIds[i];
        field->textIndex = i;
        field->setText(m == nullptr ? defaultTextValues[i] : m->textValues[i]);
        if (m != nullptr) m->registerTextField(i, field);
        addChild(field);
    }
    const int knobParams[] = {Goldenpond::OCTAVE0_PARAM, Goldenpond::VELOCITY0_PARAM,
                              Goldenpond::OCTAVE1_PARAM, Goldenpond::VELOCITY1_PARAM,
                              Goldenpond::OCTAVE2_PARAM, Goldenpond::VELOCITY2_PARAM,
                              Goldenpond::OCTAVE3_PARAM, Goldenpond::VELOCITY3_PARAM,
                              Goldenpond::BPM_PARAM, Goldenpond::CHORD_DURATION_PARAM, Goldenpond::ZOOM_PARAM,
                              Goldenpond::KEY_PARAM, Goldenpond::MODE_PARAM};
    const worldofcake::rack::goldenpond::RackPoint knobCenters[] = {
        GoldenpondLayout::kOctave0Center, GoldenpondLayout::kVelocity0Center,
        GoldenpondLayout::kOctave1Center, GoldenpondLayout::kVelocity1Center,
        GoldenpondLayout::kOctave2Center, GoldenpondLayout::kVelocity2Center,
        GoldenpondLayout::kOctave3Center, GoldenpondLayout::kVelocity3Center,
        GoldenpondLayout::kBpmCenter, GoldenpondLayout::kChorddurationCenter,
        GoldenpondLayout::kZoomCenter, GoldenpondLayout::kKeyselectCenter,
        GoldenpondLayout::kModeselectCenter};
    for (int i = 0; i < 13; ++i) {
        const auto center = knobCenters[i];
        addParam(createParamCentered<RoundBlackKnob>(mm2px(math::Vec(center.x, center.y)), m, knobParams[i]));
    }
    const auto& correctionTarget = GoldenpondLayout::kCorrectiontargetCenter;
    addParam(createParamCentered<RoundBlackSnapKnob>(mm2px(math::Vec(correctionTarget.x, correctionTarget.y)),
                                                     m, Goldenpond::CORRECTION_TARGET_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px(math::Vec(GoldenpondLayout::kResetCenter.x, GoldenpondLayout::kResetCenter.y)), m, Goldenpond::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px(math::Vec(GoldenpondLayout::kPauseCenter.x, GoldenpondLayout::kPauseCenter.y)), m, Goldenpond::PAUSE_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px(math::Vec(GoldenpondLayout::kMuteCenter.x, GoldenpondLayout::kMuteCenter.y)), m, Goldenpond::MUTE_PARAM));
    for (int i = 0; i < 8; ++i) addOutput(createOutputCentered<PJ301MPort>(mm2px(math::Vec(GoldenpondLayout::kOutputPositions[i].x, GoldenpondLayout::kOutputPositions[i].y)), m, i));
    for (int i = 0; i < 3; ++i)
        addInput(createInputCentered<PJ301MPort>(mm2px(math::Vec(GoldenpondLayout::kInputPositions[i].x, GoldenpondLayout::kInputPositions[i].y)), m, Goldenpond::CORRECT1_INPUT + i));
    for (int i = 0; i < 3; ++i)
        addOutput(createOutputCentered<PJ301MPort>(mm2px(math::Vec(GoldenpondLayout::kCorrectionOutputPositions[i].x, GoldenpondLayout::kCorrectionOutputPositions[i].y)), m, Goldenpond::CORRECT1_OUTPUT + i));
}
