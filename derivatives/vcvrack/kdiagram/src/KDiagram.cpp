#include "KDiagram.hpp"
#include "plugin.hpp"
#include <WocRackParamSync.hpp>
#include <WocRackTiming.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/kdiagram/KDiagramRackOutputsGenerated.h>
#include <worldofcake/generated/rack/kdiagram/KDiagramRackLayoutGenerated.h>
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
    namespace metadata = worldofcake::metadata::kdiagram;
    namespace layout = worldofcake::rack::kdiagram;
    const std::array<const metadata::Knob*, KDiagram::kCursorCount> kSpeedParameters{
        &metadata::kRedspeed, &metadata::kGreenspeed, &metadata::kBluespeed};
    static_assert(KDiagram::NUM_OUTPUTS == layout::kOutputCount, "Rack output IDs must match EDN");
    static_assert(layout::kLayoutOutputCount == layout::kOutputCount, "Rack sockets must match EDN");
    static_assert(KDiagram::kCursorCount == metadata::kControlOutputs.size() / 2, "Two position outputs per cursor");
    constexpr int kRotateLeftControlId = ControlIds::kRotateLeft;
    constexpr int kRotateRightControlId = ControlIds::kRotateRight;
    NVGcolor rgb(int c)
    {
        return nvgRGB((c >> 16) & 255, (c >> 8) & 255, c & 255);
    }
    struct Play : OpaqueWidget
    {
        KDiagram* module = nullptr;
        worldofcake::CoordinateMapper mapper() const {
            return {{-1, 1}, {1, -1}, {0, 0}, {box.size.x, box.size.y}};
        }
        void onButton(const ButtonEvent& e) override
        {
            Widget::onButton(e);
            if (module && e.button == GLFW_MOUSE_BUTTON_LEFT && e.action == GLFW_PRESS && !e.isConsumed()) {
                const auto local = mapper().backward(e.pos.x, e.pos.y);
                module->click(local.x, local.y);
                e.consume(this);
            }
        }
        void draw(const DrawArgs& a) override
        {
            const auto map = mapper();
            auto point = [&map](double x, double y) { return map.forward(x, y); };
            nvgBeginPath(a.vg);
            nvgRect(a.vg, 0, 0, box.size.x, box.size.y);
            nvgFillColor(a.vg, rgb(metadata::model::kPaletteScore[0]));
            nvgFill(a.vg);
            if (module) {
                auto s = module->runner->latestVisualSnapshot();
                nvgSave(a.vg);
                nvgScissor(a.vg, 0, 0, box.size.x, box.size.y);
                // Match OpenFL's network boundary. The Haxe model supplies a
                // normalized radius, and the playfield maps -1..1 to its width.
                nvgBeginPath(a.vg);
                nvgCircle(a.vg, point(0, 0).x, point(0, 0).y,
                          static_cast<float>(map.lengthForward(s.radius)));
                nvgStrokeColor(a.vg, rgb(metadata::model::kPaletteScore[3]));
                nvgStrokeWidth(a.vg, 1.0f);
                nvgStroke(a.vg);
                nvgStrokeColor(a.vg, rgb(metadata::model::kPaletteScore[2]));
                for (auto& arc : s.arcs)
                    if (arc.source >= 0 && arc.destination >= 0 && (size_t)arc.source < s.nodes.size() &&
                        (size_t)arc.destination < s.nodes.size()) {
                        auto& p = s.nodes[arc.source];
                        auto& q = s.nodes[arc.destination];
                        nvgBeginPath(a.vg);
                        nvgMoveTo(a.vg, point(p.x, p.y).x, point(p.x, p.y).y);
                        nvgLineTo(a.vg, point(q.x, q.y).x, point(q.x, q.y).y);
                        nvgStroke(a.vg);
                    }
                for (auto& n : s.nodes) {
                    nvgBeginPath(a.vg);
                    const auto at = point(n.x, n.y);
                    const float x = at.x, y = at.y, radius = map.lengthForward(0.04);
                    if (n.type == 3) {
                        nvgMoveTo(a.vg, x-radius*1.35f, y);
                        nvgLineTo(a.vg, x, y-radius*0.65f);
                        nvgLineTo(a.vg, x+radius*1.35f, y);
                        nvgLineTo(a.vg, x, y+radius*0.65f);
                        nvgClosePath(a.vg);
                    } else if (n.type == 2) nvgRect(a.vg, x-radius, y-radius, radius*2, radius*2);
                    else if (n.type == 1) {
                        nvgMoveTo(a.vg, x, y-radius);
                        nvgLineTo(a.vg, x+radius, y+radius);
                        nvgLineTo(a.vg, x-radius, y+radius);
                        nvgClosePath(a.vg);
                    } else nvgCircle(a.vg, x, y, radius);
                    nvgFillColor(a.vg, rgb(metadata::model::kPaletteScore[0]));
                    nvgFill(a.vg);
                    nvgStrokeColor(a.vg, rgb(metadata::model::kPaletteScore[1]));
                    nvgStrokeWidth(a.vg, 1.0f);
                    nvgStroke(a.vg);
                }
                for (int i = 0; i < static_cast<int>(KDiagram::kCursorCount); ++i) {
                    auto& c = s.cursors[i];
                    nvgBeginPath(a.vg);
                    nvgCircle(a.vg, point(c.x, c.y).x, point(c.x, c.y).y, i == s.selectedCursor ? 5 : 3.5f);
                    nvgFillColor(a.vg, rgb(kSpeedParameters[i]->colour));
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
    configButton(RESET_PARAM, metadata::kReset.label);
    configSwitch(TERMINUS_PARAM, 0, 1, 1, metadata::kTerminus.label);
    configSwitch(PAUSE_PARAM, 0, 1, 0, metadata::kPause.label);
    for (int i = 0; i < static_cast<int>(KDiagram::kCursorCount); ++i) {
        const auto* speed = kSpeedParameters[i];
        configParam(SPEED_CURSOR1_PARAM + i, 0.f, 1.f,
                    static_cast<float>(metadata::normalize(*speed, speed->defaultValue)), speed->label);
    }
    std::vector<std::string> cursorLabels;
    for (std::size_t i = 0; i < metadata::kSelectcursor.choiceCount; ++i)
        cursorLabels.emplace_back(metadata::kSelectcursor.choices[i].label);
    configSwitch(CURSOR_SELECT_PARAM, 0, static_cast<float>(metadata::kSelectcursor.choiceCount - 1),
                 metadata::kSelectcursor.defaultIndex, metadata::kSelectcursor.label, cursorLabels);
    std::vector<std::string> scaleLabels;
    for (std::size_t i = 0; i < worldofcake::metadata::kdiagram::kScaleselect.choiceCount; ++i)
        scaleLabels.emplace_back(worldofcake::metadata::kdiagram::kScaleselect.choices[i].label);
    configSwitch(SCALE_PARAM, 0.f,
                 static_cast<float>(worldofcake::metadata::kdiagram::kScaleselect.choiceCount - 1),
                 static_cast<float>(worldofcake::metadata::kdiagram::kScaleselect.defaultIndex),
                 metadata::kScaleselect.label, scaleLabels);
    configButton(ROT_CCW_PARAM, metadata::kRotate_left.label);
    configButton(ROT_CW_PARAM, metadata::kRotate_right.label);
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
    for (int i = 0; i < static_cast<int>(KDiagram::kCursorCount); i++) {
        const auto* parameter = kSpeedParameters[i];
        worldofcake::rack::syncControlValue(
            worldofcake::metadata::kdiagram::denormalize(*parameter, params[SPEED_CURSOR1_PARAM + i].getValue()),
            lastSpeed[i], 1e-5, ControlIds::speedUid(i), [this](int id, double value) { send(id, value); });
    }
    worldofcake::rack::syncControlValue(
        worldofcake::metadata::kdiagram::denormalize(worldofcake::metadata::kdiagram::kNote_length,
                                                     params[NOTE_LENGTH_PARAM].getValue()),
        lastNoteLength, 1e-6, ControlIds::kNoteLength, [this](int id, double value) { send(id, value); });
    const int terminus = params[TERMINUS_PARAM].getValue() > 0.5f ? 1 : 0;
    worldofcake::rack::syncControlValueExact(terminus, lastTerminus, ControlIds::kTerminus,
        [this](int id, double value) { send(id, value); });
    int cur = (int)std::round(params[CURSOR_SELECT_PARAM].getValue());
    worldofcake::rack::syncControlValueExact(cur, lastCursor, ControlIds::kCursorSelect,
                                             [this](int id, double value) { send(id, value); });
    int scaleIdx = (int)std::round(params[SCALE_PARAM].getValue());
    worldofcake::rack::syncBoundedControlValueExact(scaleIdx, 0, static_cast<int>(metadata::kScaleselect.choiceCount - 1), lastScaleIdx, ControlIds::kScaleSelect,
                                                    [this](int id, double value) { send(id, value); });
    worldofcake::rack::syncTransport(params[PAUSE_PARAM].getValue(), lastPause, params[RESET_PARAM].getValue(),
                                     lastReset, [this](const worldofcake::bridge::ControlCommand& c) { runner->enqueueHostCommand(c); });
    worldofcake::rack::sendButtonRisingEdge(params[ROT_CCW_PARAM].getValue(), lastL, kRotateLeftControlId,
                                            [this](int id, double v) { send(id, v); });
    worldofcake::rack::sendButtonRisingEdge(params[ROT_CW_PARAM].getValue(), lastR, kRotateRightControlId,
                                            [this](int id, double v) { send(id, v); });
    // Events are due on arrival (the runner releases them at model time).
    // Cursor i plays on MIDI channel base + i; its gate follows its sounding notes.
    const int firstChannel = baseMidiChannel;
    worldofcake::bridge::PreparedEvent e;
    int n = 0;
    while (n++ < 256 && runner->popPreparedEvent(e))
        notes.schedule(0.0, e);
    notes.emitDue(0.0, [this, firstChannel](double, const worldofcake::bridge::PreparedEvent& ev) {
        const int i = ev.channel - firstChannel;
        if (ev.type == worldofcake::bridge::NoteOutputScheduler::kNoteOn && i >= 0 && i < static_cast<int>(KDiagram::kCursorCount))
            pitchV[i] = worldofcake::rack::midiNoteToOneVoltPerOctave(ev.data2);
    });
    for (int i = 0; i < static_cast<int>(KDiagram::kCursorCount); ++i) {
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
    p->box.pos = mm2px({layout::kPlayarea.x, layout::kPlayarea.y});
    p->box.size = mm2px({layout::kPlayarea.width, layout::kPlayarea.height});
    addChild(p);
    auto at = [](const layout::RackPoint& point) { return mm2px(math::Vec(point.x, point.y)); };
    addParam(createParamCentered<Rogan2PSRed>(at(layout::kRedspeedCenter), m, KDiagram::SPEED_CURSOR1_PARAM));
    addParam(createParamCentered<Rogan2PSGreen>(at(layout::kGreenspeedCenter), m, KDiagram::SPEED_CURSOR2_PARAM));
    addParam(createParamCentered<Rogan2PSBlue>(at(layout::kBluespeedCenter), m, KDiagram::SPEED_CURSOR3_PARAM));
    addParam(createParamCentered<CKSSThreeHorizontal>(at(layout::kSelectcursorCenter), m, KDiagram::CURSOR_SELECT_PARAM));
    addParam(createParamCentered<RoundBlackSnapKnob>(at(layout::kScaleselectCenter), m, KDiagram::SCALE_PARAM));
    addParam(createParamCentered<RoundBlackKnob>(at(layout::kNoteLengthCenter), m, KDiagram::NOTE_LENGTH_PARAM));
    addParam(createParamCentered<VCVLatch>(at(layout::kTerminusCenter), m, KDiagram::TERMINUS_PARAM));
    addParam(createParamCentered<LEDButton>(at(layout::kResetCenter), m, KDiagram::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(at(layout::kPauseCenter), m, KDiagram::PAUSE_PARAM));
    addParam(createParamCentered<LEDButton>(at(layout::kRotateLeftCenter), m, KDiagram::ROT_CCW_PARAM));
    addParam(createParamCentered<LEDButton>(at(layout::kRotateRightCenter), m, KDiagram::ROT_CW_PARAM));
    for (int i = 0; i < layout::kOutputCount; ++i)
        addOutput(createOutputCentered<PJ301MPort>(at(layout::kOutputPositions[i]), m, i));
}
