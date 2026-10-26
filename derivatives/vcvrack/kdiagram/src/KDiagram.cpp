#include "KDiagram.hpp"
#include "plugin.hpp"
#include <WocRackParamSync.hpp>
#include <WocRackTiming.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/kdiagram/KDiagramRackOutputsGenerated.h>
#include <worldofcake/generated/kdiagram/KdiagramControlMetadataGenerated.h>
#include <GLFW/glfw3.h>
#include <asset.hpp>
#include <componentlibrary.hpp>
#include <widget/OpaqueWidget.hpp>
#include <chrono>
#include <string>
using namespace rack::widget;
using namespace rack::app;
namespace
{
    namespace ControlIds = worldofcake::control::kdiagram;
    constexpr int kRotateLeftControlId = ControlIds::kRotateLeft;
    constexpr int kRotateRightControlId = ControlIds::kRotateRight;
    float px(float x, float w)
    {
        return (x + 1) * .5 * w;
    }
    float py(float y, float h)
    {
        return (1 - y) * .5 * h;
    }
    NVGcolor rgb(int c)
    {
        return nvgRGB((c >> 16) & 255, (c >> 8) & 255, c & 255);
    }
    struct Play : OpaqueWidget
    {
        KDiagram* module = nullptr;
        void onButton(const ButtonEvent& e) override
        {
            Widget::onButton(e);
            if (module && e.button == GLFW_MOUSE_BUTTON_LEFT && e.action == GLFW_PRESS && !e.isConsumed()) {
                module->click(e.pos.x / box.size.x * 2 - 1, 1 - e.pos.y / box.size.y * 2);
                e.consume(this);
            }
        }
        void draw(const DrawArgs& a) override
        {
            nvgBeginPath(a.vg);
            nvgRect(a.vg, 0, 0, box.size.x, box.size.y);
            nvgFillColor(a.vg, nvgRGB(18, 20, 26));
            nvgFill(a.vg);
            if (module) {
                auto s = module->runner->latestVisualSnapshot();
                nvgSave(a.vg);
                nvgScissor(a.vg, 0, 0, box.size.x, box.size.y);
                // Match OpenFL's network boundary. The Haxe model supplies a
                // normalized radius, and the playfield maps -1..1 to its width.
                nvgBeginPath(a.vg);
                nvgCircle(a.vg, px(0, box.size.x), py(0, box.size.y),
                          static_cast<float>(s.radius * box.size.x * 0.5));
                nvgStrokeColor(a.vg, nvgRGB(200, 200, 100));
                nvgStrokeWidth(a.vg, 1.0f);
                nvgStroke(a.vg);
                nvgStrokeColor(a.vg, nvgRGB(255, 200, 100));
                for (auto& arc : s.arcs)
                    if (arc.source >= 0 && arc.destination >= 0 && (size_t)arc.source < s.nodes.size() &&
                        (size_t)arc.destination < s.nodes.size()) {
                        auto& p = s.nodes[arc.source];
                        auto& q = s.nodes[arc.destination];
                        nvgBeginPath(a.vg);
                        nvgMoveTo(a.vg, px(p.x, box.size.x), py(p.y, box.size.y));
                        nvgLineTo(a.vg, px(q.x, box.size.x), py(q.y, box.size.y));
                        nvgStroke(a.vg);
                    }
                for (auto& n : s.nodes) {
                    nvgBeginPath(a.vg);
                    nvgCircle(a.vg, px(n.x, box.size.x), py(n.y, box.size.y), 4);
                    nvgFillColor(a.vg, nvgRGB(120, 120, 120));
                    nvgFill(a.vg);
                }
                for (int i = 0; i < 3; ++i) {
                    auto& c = s.cursors[i];
                    nvgBeginPath(a.vg);
                    nvgCircle(a.vg, px(c.x, box.size.x), py(c.y, box.size.y), i == s.selectedCursor ? 8 : 6);
                    nvgFillColor(a.vg, rgb(c.colour));
                    nvgFill(a.vg);
                }
                nvgRestore(a.vg);
            }
            OpaqueWidget::draw(a);
        }
    };
} // namespace
KDiagram::KDiagram()
{
    config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
    configParam(SIM_RATE_PARAM, 0, 1, .5, "Display rate");
    configButton(RESET_PARAM, "Reset");
    configSwitch(PAUSE_PARAM, 0, 1, 0, "Pause", {"Run", "Pause"});
    for (int i = 0; i < 3; ++i) {
        const auto* speed = std::array<const worldofcake::metadata::kdiagram::Knob*, 3>{
            &worldofcake::metadata::kdiagram::kRedspeed,
            &worldofcake::metadata::kdiagram::kGreenspeed,
            &worldofcake::metadata::kdiagram::kBluespeed}[static_cast<std::size_t>(i)];
        configParam(SPEED_CURSOR1_PARAM + i, 0.f, 1.f,
                    static_cast<float>((speed->defaultValue - speed->minimum) / (speed->maximum - speed->minimum)),
                    "Cursor " + std::to_string(i + 1) + " speed");
    }
    configParam(CHANNEL_BASE_PARAM, 0, 13, 0, "Base MIDI channel");
    paramQuantities[CHANNEL_BASE_PARAM]->snapEnabled = true;
    configParam(CURSOR_SELECT_PARAM, 0, 2, 0, "Selected cursor");
    paramQuantities[CURSOR_SELECT_PARAM]->snapEnabled = true;
    std::vector<std::string> scaleLabels;
    for (std::size_t i = 0; i < worldofcake::metadata::kdiagram::kScaleselect.choiceCount; ++i)
        scaleLabels.emplace_back(worldofcake::metadata::kdiagram::kScaleselect.choices[i].label);
    configSwitch(SCALE_PARAM, 0.f,
                 static_cast<float>(worldofcake::metadata::kdiagram::kScaleselect.choiceCount - 1),
                 static_cast<float>(worldofcake::metadata::kdiagram::kScaleselect.defaultIndex),
                 "Scale", scaleLabels);
    configButton(ROT_CCW_PARAM, "Rotate left");
    configButton(ROT_CW_PARAM, "Rotate right");
    const auto& noteLength = worldofcake::metadata::kdiagram::kNote_length;
    configParam(NOTE_LENGTH_PARAM, 0.f, 1.f,
                static_cast<float>(worldofcake::metadata::kdiagram::normalize(noteLength, noteLength.defaultValue)),
                noteLength.label);
    for (int i = 0; i < worldofcake::rack::kdiagram::kOutputCount; ++i)
        configOutput(i, worldofcake::rack::kdiagram::kOutputLabels[i]);
    int seed = (int)std::chrono::high_resolution_clock::now().time_since_epoch().count();
    runner.reset(new worldofcake::bridge::KDiagramControlRunner(seed));
    runner->start(worldofcake::rack::kControlPeriodSeconds);
}
KDiagram::~KDiagram()
{
    if (runner)
        runner->stop();
}
void KDiagram::click(float x, float y)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::playAreaClick;
    c.sequence = guiSequence++;
    c.x = x;
    c.y = y;
    runner->enqueueGuiCommand(c);
}
void KDiagram::send(int id, double v)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::setValue;
    c.sequence = hostSequence++;
    c.controlId = id;
    c.value = v;
    runner->enqueueHostCommand(c);
}
void KDiagram::process(const ProcessArgs& a)
{
    for (int i = 0; i < 3; i++) {
        const auto* parameter = std::array<const worldofcake::metadata::kdiagram::Knob*, 3>{
            &worldofcake::metadata::kdiagram::kRedspeed,
            &worldofcake::metadata::kdiagram::kGreenspeed,
            &worldofcake::metadata::kdiagram::kBluespeed}[static_cast<std::size_t>(i)];
        worldofcake::rack::syncControlValue(
            worldofcake::metadata::kdiagram::denormalize(*parameter, params[SPEED_CURSOR1_PARAM + i].getValue()),
            lastSpeed[i], 1e-5, ControlIds::speedUid(i), [this](int id, double value) { send(id, value); });
    }
    worldofcake::rack::syncControlValue(
        worldofcake::metadata::kdiagram::denormalize(worldofcake::metadata::kdiagram::kNote_length,
                                                     params[NOTE_LENGTH_PARAM].getValue()),
        lastNoteLength, 1e-6, ControlIds::kNoteLength, [this](int id, double value) { send(id, value); });
    int ch = (int)std::round(params[CHANNEL_BASE_PARAM].getValue());
    worldofcake::rack::syncControlValueExact(ch, lastChannel, ControlIds::kChannel,
                                             [this](int id, double value) { send(id, value + 1); });
    int cur = (int)std::round(params[CURSOR_SELECT_PARAM].getValue());
    worldofcake::rack::syncControlValueExact(cur, lastCursor, ControlIds::kCursorSelect,
                                             [this](int id, double value) { send(id, value); });
    int scaleIdx = (int)std::round(params[SCALE_PARAM].getValue());
    worldofcake::rack::syncBoundedControlValueExact(scaleIdx, 0, 5, lastScaleIdx, ControlIds::kScaleSelect,
                                                    [this](int id, double value) { send(id, value); });
    worldofcake::rack::syncTransport(params[PAUSE_PARAM].getValue(), lastPause, params[RESET_PARAM].getValue(),
                                     lastReset, [this](const worldofcake::bridge::ControlCommand& c) { runner->enqueueHostCommand(c); });
    worldofcake::rack::sendButtonRisingEdge(params[ROT_CCW_PARAM].getValue(), lastL, kRotateLeftControlId,
                                            [this](int id, double v) { send(id, v); });
    worldofcake::rack::sendButtonRisingEdge(params[ROT_CW_PARAM].getValue(), lastR, kRotateRightControlId,
                                            [this](int id, double v) { send(id, v); });
    // Events are due on arrival (the runner releases them at model time).
    // Cursor i plays on MIDI channel base + i; its gate follows its sounding notes.
    const int firstChannel = lastChannel + 1;
    worldofcake::bridge::PreparedEvent e;
    int n = 0;
    while (n++ < 256 && runner->popPreparedEvent(e))
        notes.schedule(0.0, e);
    notes.emitDue(0.0, [this, firstChannel](double, const worldofcake::bridge::PreparedEvent& ev) {
        const int i = ev.channel - firstChannel;
        if (ev.type == worldofcake::bridge::NoteOutputScheduler::kNoteOn && i >= 0 && i < 3)
            pitchV[i] = worldofcake::rack::midiNoteToOneVoltPerOctave(ev.data2);
    });
    for (int i = 0; i < 3; ++i) {
        int o = GATE1_OUTPUT + 4 * i;
        const bool gate = gates[i].process(notes.soundingNotes(firstChannel + i), notes.noteOnCount(firstChannel + i), a.sampleTime);
        outputs[o].setVoltage(worldofcake::rack::gate10V(gate));
        // Cursor i's X and Y are control outputs 2i and 2i+1 (0..1, decided in Haxe) as 0..10 V.
        outputs[o + 1].setVoltage(10.0f * runner->controlOutputValue(i * 2 + 1));
        outputs[o + 2].setVoltage(10.0f * runner->controlOutputValue(i * 2));
        outputs[o + 3].setVoltage(pitchV[i]);
    }
}
KDiagramWidget::KDiagramWidget(KDiagram* m)
{
    setModule(m);
    setPanel(createPanel(asset::plugin(pluginInstance, "generated/KDiagram.svg")));
    addChild(createWidget<ScrewSilver>({RACK_GRID_WIDTH, 0}));
    addChild(createWidget<ScrewSilver>({box.size.x - 2 * RACK_GRID_WIDTH, 0}));
    auto* p = new Play;
    p->module = m;
    p->box.pos = mm2px({52, 18});
    p->box.size = mm2px({96, 95});
    addChild(p);
    float y[3] = {38, 56, 74};
    addParam(createParamCentered<Rogan2PSRed>(mm2px({11, y[0]}), m, KDiagram::SPEED_CURSOR1_PARAM));
    addParam(createParamCentered<Rogan2PSGreen>(mm2px({11, y[1]}), m, KDiagram::SPEED_CURSOR2_PARAM));
    addParam(createParamCentered<Rogan2PSBlue>(mm2px({11, y[2]}), m, KDiagram::SPEED_CURSOR3_PARAM));
    addParam(createParamCentered<RoundBlackKnob>(mm2px({30, 56}), m, KDiagram::NOTE_LENGTH_PARAM));
    addParam(createParamCentered<RoundBlackSnapKnob>(mm2px({11, 92}), m, KDiagram::CHANNEL_BASE_PARAM));
    addParam(createParamCentered<CKSSThree>(mm2px({28, 92}), m, KDiagram::CURSOR_SELECT_PARAM));
    addParam(createParamCentered<RoundBlackSnapKnob>(mm2px({44, 92}), m, KDiagram::SCALE_PARAM));
    addParam(createParamCentered<RoundBlackKnob>(mm2px({11, 110}), m, KDiagram::SIM_RATE_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px({11, 122}), m, KDiagram::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px({26, 122}), m, KDiagram::PAUSE_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px({44, 122}), m, KDiagram::ROT_CCW_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px({60, 122}), m, KDiagram::ROT_CW_PARAM));
    float ox[4] = {159, 174, 189, 204}, oy[3] = {30, 52, 74};
    for (int i = 0; i < 3; ++i)
        for (int j = 0; j < 4; ++j)
            addOutput(createOutputCentered<PJ301MPort>(mm2px({ox[j], oy[i]}), m, KDiagram::GATE1_OUTPUT + 4 * i + j));
}
