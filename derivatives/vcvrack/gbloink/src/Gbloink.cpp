#include "Gbloink.hpp"
#include "plugin.hpp"
#include <WocRackParamSync.hpp>
#include <WocRackTiming.hpp>
#include <WocRackStateJson.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/gbloink/GbloinkRackOutputsGenerated.h>
#include <worldofcake/generated/rack/gbloink/GbloinkRackLayoutGenerated.h>
#include <worldofcake/generated/gbloink/GbloinkControlMetadataGenerated.h>

#include <GLFW/glfw3.h>
#include <asset.hpp>
#include <componentlibrary.hpp>
#include <helpers.hpp>
#include <jansson.h>
#include <ui/MenuSeparator.hpp>
#include <string>
#include <algorithm>
#include <widget/OpaqueWidget.hpp>
#include <chrono>
#include <logger.hpp>

using namespace rack::widget;
using namespace rack::app;

namespace
{

    constexpr float kLocalW = 700.f;
    constexpr float kLocalH = 500.f;
    namespace ControlIds = worldofcake::control::gbloink;
    const auto kSpeedParameters = std::array<const worldofcake::metadata::gbloink::Knob*, 3>{
        &worldofcake::metadata::gbloink::kRedspeed,
        &worldofcake::metadata::gbloink::kGreenspeed,
        &worldofcake::metadata::gbloink::kBluespeed};
    /** Matches generated Gbloink Rack panel playfield (dark inset on light panel). */
    constexpr int kPlayfieldBgR = 18;
    constexpr int kPlayfieldBgG = 20;
    constexpr int kPlayfieldBgB = 26;

    NVGcolor nvgRgbPacked(int rgb)
    {
        int r = (rgb >> 16) & 255;
        int g = (rgb >> 8) & 255;
        int b = rgb & 255;
        return nvgRGB(r, g, b);
    }

    struct GbloinkPlayWidget : OpaqueWidget
    {
        Gbloink* module = NULL;

        void onButton(const ButtonEvent& e) override
        {
            Widget::onButton(e);
            if (!module) {
                return;
            }
            if (e.button == GLFW_MOUSE_BUTTON_LEFT && e.action == GLFW_PRESS && !e.isConsumed()) {
                const float lx = (box.size.x > 0.f) ? e.pos.x / box.size.x * kLocalW : 0.f;
                const float ly = (box.size.y > 0.f) ? e.pos.y / box.size.y * kLocalH : 0.f;
                module->playAreaClick(lx, ly);
                e.consume(this);
            }
        }

        void draw(const DrawArgs& args) override
        {
            NVGcontext* vg = args.vg;
            nvgBeginPath(vg);
            nvgRect(vg, 0.f, 0.f, box.size.x, box.size.y);
            nvgFillColor(vg, nvgRGB(kPlayfieldBgR, kPlayfieldBgG, kPlayfieldBgB));
            nvgFill(vg);

            if (!module) {
                OpaqueWidget::draw(args);
                return;
            }

            const auto snapshot = module->runner->latestVisualSnapshot();

            nvgSave(vg);
            nvgScissor(vg, 0.f, 0.f, box.size.x, box.size.y);

            for (const auto& ball : snapshot.balls) {
                const float bx = ball.x / kLocalW * box.size.x;
                const float by = ball.y / kLocalH * box.size.y;
                const float rad = ball.radius / kLocalW * box.size.x;
                const int col = ball.colour;
                nvgBeginPath(vg);
                nvgCircle(vg, bx, by, std::max(1.5f, rad));
                nvgFillColor(vg, nvgRgbPacked(col));
                nvgFill(vg);
            }

            for (const auto& block : snapshot.blocks) {
                const float L = block.left / kLocalW * box.size.x;
                const float T = block.top / kLocalH * box.size.y;
                const float R = block.right / kLocalW * box.size.x;
                const float B = block.bottom / kLocalH * box.size.y;
                const int col = block.colour;
                const int r = (col >> 16) & 255;
                const int g = (col >> 8) & 255;
                const int b = col & 255;
                nvgBeginPath(vg);
                nvgRect(vg, L, T, R - L, B - T);
                nvgFillColor(vg, nvgTransRGBA(nvgRGB(r, g, b), 200));
                nvgFill(vg);
            }

            nvgRestore(vg);

            OpaqueWidget::draw(args);
        }
    };

} // namespace

Gbloink::Gbloink()
{
    config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
    for (int i = 0; i < 3; i++) {
        const auto* speed = kSpeedParameters[static_cast<std::size_t>(i)];
        configParam(SPEED_BALL1_PARAM + i, 0.f, 1.f,
                    static_cast<float>(worldofcake::metadata::gbloink::normalize(*speed, speed->defaultValue)),
                    "Ball " + std::to_string(i + 1) + " speed");
    }
    configSwitch(SCALE_PARAM, 0.f, 5.f, 0.f, "Scale",
                 {
                     "Chromatic",
                     "Major",
                     "Minor",
                     "Harm minor",
                     "Mel minor",
                     "Min blues",
                 });
    configButton(RESET_PARAM, "Reset");
    configSwitch(PAUSE_PARAM, 0.f, 1.f, 0.f, "Pause", {"Run", "Pause"});
    configSwitch(MUTE_PARAM, 0.f, 1.f, 0.f, "Mute output", {"Output", "Muted"});
    configSwitch(EDGE_NOTES_PARAM, 0.f, 1.f, 0.f, "Wall notes", {"Off", "On"});
    for (int i = 0; i < worldofcake::rack::gbloink::kOutputCount; i++) {
        configOutput(i, worldofcake::rack::gbloink::kOutputLabels[i]);
    }

    const auto seed = static_cast<int>(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    runner.reset(new worldofcake::bridge::GbloinkControlRunner(kLocalW, kLocalH, seed));
    runner->start(worldofcake::rack::kControlPeriodSeconds, worldofcake::rack::kLogicalDeltaSeconds);
}

Gbloink::~Gbloink()
{
    if (runner)
        runner->stop();
}

void Gbloink::playAreaClick(float localX, float localY)
{
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::playAreaClick;
    command.sequence = guiSequence.fetch_add(1, std::memory_order_relaxed);
    command.x = localX;
    command.y = localY;
    runner->enqueueGuiCommand(command);
}

void Gbloink::enqueueHostValue(int controlId, double value)
{
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::setValue;
    command.sequence = hostSequence++;
    command.controlId = controlId;
    command.value = value;
    runner->enqueueHostCommand(command);
}

void Gbloink::syncPanelToRunner()
{
    worldofcake::rack::syncIndexedControlValues(
        3, ControlIds::kSpeedBase, lastSpeed, 1e-5,
        [this](int i) {
            const auto* speed = kSpeedParameters[static_cast<std::size_t>(i)];
            return worldofcake::metadata::gbloink::denormalize(*speed, params[SPEED_BALL1_PARAM + i].getValue());
        },
        [this](int id, double value) { enqueueHostValue(id, value); });
    worldofcake::rack::syncPauseLatch(params[PAUSE_PARAM].getValue(), lastPause, ControlIds::kPause,
                                     [this](int id, double value) { enqueueHostValue(id, value); });
    worldofcake::rack::syncPauseLatch(params[MUTE_PARAM].getValue(), lastMute, ControlIds::kMute,
                                     [this](int id, double value) { enqueueHostValue(id, value); });
    const float resetValue = params[RESET_PARAM].getValue();
    if (ignoreResetUntilReleased) {
        lastResetButton = resetValue;
        if (resetValue <= 0.5f)
            ignoreResetUntilReleased = false;
        else
            params[RESET_PARAM].setValue(0.f);
    } else {
        worldofcake::rack::sendButtonRisingEdge(resetValue, lastResetButton, ControlIds::kReset,
                                                [this](int id, double value) { enqueueHostValue(id, value); });
    }

    const int scaleIdx = (int)std::round(params[SCALE_PARAM].getValue());
    worldofcake::rack::syncBoundedControlValueExact(scaleIdx, 0, 5, lastScaleIdx, ControlIds::kScaleSelect,
                                                    [this](int id, double value) { enqueueHostValue(id, value); });

    const bool wantEdgeNotes = params[EDGE_NOTES_PARAM].getValue() > 0.5f;
    const int wantEdgeNotesI = wantEdgeNotes ? 1 : 0;
    worldofcake::rack::syncControlValueExact(wantEdgeNotesI, lastEdgeNotes, ControlIds::kEdgeNotes,
                                             [this](int id, double value) { enqueueHostValue(id, value); });
}

void Gbloink::process(const ProcessArgs& args)
{
    syncPanelToRunner();
    worldofcake::bridge::PreparedEvent event;
    int safetyPops = 0;
    while (runner->popPreparedEvent(event) && safetyPops++ < 256) {
        if (event.type == 0) {
            const int channel = event.channel;
            const int note = event.data2;
            const int bi = channel - 1;
            if (bi >= 0 && bi < 3) {
                pitchV[bi] = worldofcake::rack::midiNoteToOneVoltPerOctave(note);
                // Short trigger on block hit (not a sustained gate); ~1 ms at audio rate.
                gatePulse[bi].trigger(1e-3f);
            }
        }
    }

    for (int i = 0; i < 3; i++) {
        if (params[MUTE_PARAM].getValue() > 0.5f) {
            outputs[GATE_BALL1_OUTPUT + 2 * i].setVoltage(0.f);
            outputs[PITCH_BALL1_OUTPUT + 2 * i].setVoltage(0.f);
            continue;
        }
        const bool high = gatePulse[i].process(args.sampleTime);
        outputs[GATE_BALL1_OUTPUT + 2 * i].setVoltage(worldofcake::rack::gate10V(high));
        outputs[PITCH_BALL1_OUTPUT + 2 * i].setVoltage(pitchV[i]);
    }
}

json_t* Gbloink::dataToJson()
{
    const auto call = autosaveCalls.fetch_add(1, std::memory_order_relaxed) + 1;
    INFO("WorldOfCake-Gbloink: stateJson autosave #%llu", static_cast<unsigned long long>(call));
    return worldofcake::rack::makeStateJson(runner->exportStateJson());
}

void Gbloink::dataFromJson(json_t* rootJ)
{
    auto state = worldofcake::rack::readStateJson(rootJ);
    if (state.empty() && rootJ) {
        json_t* legacyBlocks = json_object_get(rootJ, "blocksJson");
        if (legacyBlocks && json_is_string(legacyBlocks)) {
            const char* legacyState = json_string_value(legacyBlocks);
            if (legacyState)
                state = legacyState;
        }
    }
    if (state.empty())
        return;

    runner->importStateJson(state);
    // Rack serializes momentary buttons; never replay a saved reset on reload.
    params[RESET_PARAM].setValue(0.f);
    lastResetButton = 0.f;
    ignoreResetUntilReleased = true;
    const auto snapshot = runner->latestVisualSnapshot();
    params[PAUSE_PARAM].setValue(snapshot.paused ? 1.f : 0.f);
    lastPause = snapshot.paused ? 1 : 0;
    params[SCALE_PARAM].setValue(static_cast<float>(snapshot.scaleIndex));
    lastScaleIdx = snapshot.scaleIndex;
    params[EDGE_NOTES_PARAM].setValue(snapshot.edgeNotes ? 1.f : 0.f);
    lastEdgeNotes = snapshot.edgeNotes ? 1 : 0;
}

GbloinkWidget::GbloinkWidget(Gbloink* module)
{
    setModule(module);
    setPanel(createPanel(asset::plugin(pluginInstance, "generated/Gbloink.svg")));

    addChild(createWidget<ScrewSilver>(math::Vec(RACK_GRID_WIDTH, 0)));
    addChild(createWidget<ScrewSilver>(math::Vec(box.size.x - 2 * RACK_GRID_WIDTH, 0)));
    addChild(createWidget<ScrewSilver>(math::Vec(RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));
    addChild(
        createWidget<ScrewSilver>(math::Vec(box.size.x - 2 * RACK_GRID_WIDTH, RACK_GRID_HEIGHT - RACK_GRID_WIDTH)));

    auto* play = new GbloinkPlayWidget;
    play->module = module;
    play->box.pos = mm2px(math::Vec(worldofcake::rack::gbloink::kPlayarea.x,
                                    worldofcake::rack::gbloink::kPlayarea.y));
    play->box.size = mm2px(math::Vec(worldofcake::rack::gbloink::kPlayarea.width,
                                     worldofcake::rack::gbloink::kPlayarea.height));
    addChild(play);

    using worldofcake::rack::gbloink::RackPoint;
    const RackPoint& redSpeed = worldofcake::rack::gbloink::kRedspeedCenter;
    const RackPoint& greenSpeed = worldofcake::rack::gbloink::kGreenspeedCenter;
    const RackPoint& blueSpeed = worldofcake::rack::gbloink::kBluespeedCenter;
    addParam(createParamCentered<Rogan2PSRed>(mm2px(math::Vec(redSpeed.x, redSpeed.y)), module,
                                               Gbloink::SPEED_BALL1_PARAM));
    addParam(createParamCentered<Rogan2PSGreen>(mm2px(math::Vec(greenSpeed.x, greenSpeed.y)), module,
                                                 Gbloink::SPEED_BALL2_PARAM));
    addParam(createParamCentered<Rogan2PSBlue>(mm2px(math::Vec(blueSpeed.x, blueSpeed.y)), module,
                                                Gbloink::SPEED_BALL3_PARAM));
    const RackPoint& scale = worldofcake::rack::gbloink::kScaleselectCenter;
    const RackPoint& edge = worldofcake::rack::gbloink::kEdgeNotesCenter;
    const RackPoint& reset = worldofcake::rack::gbloink::kResetCenter;
    const RackPoint& pause = worldofcake::rack::gbloink::kPauseCenter;
    addParam(createParamCentered<RoundBlackSnapKnob>(mm2px(math::Vec(scale.x, scale.y)), module, Gbloink::SCALE_PARAM));
    addParam(createParamCentered<CKSS>(mm2px(math::Vec(edge.x, edge.y)), module, Gbloink::EDGE_NOTES_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px(math::Vec(reset.x, reset.y)), module, Gbloink::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px(math::Vec(pause.x, pause.y)), module, Gbloink::PAUSE_PARAM));
    const auto& mute = worldofcake::rack::gbloink::kMuteCenter;
    addParam(createParamCentered<VCVLatch>(mm2px(math::Vec(mute.x, mute.y)), module, Gbloink::MUTE_PARAM));

    // Generated Rack output order: red gate, red pitch, green gate, green pitch, blue gate, blue pitch.
    for (int i = 0; i < worldofcake::rack::gbloink::kOutputCount; i++) {
        const RackPoint& output = worldofcake::rack::gbloink::kOutputPositions[i];
        addOutput(createOutputCentered<PJ301MPort>(mm2px(math::Vec(output.x, output.y)), module, i));
    }
}

void GbloinkWidget::appendContextMenu(ui::Menu* menu)
{
    ModuleWidget::appendContextMenu(menu);
    Gbloink* m = getModule<Gbloink>();
    if (!m) {
        return;
    }
    menu->addChild(new ui::MenuSeparator);
    menu->addChild(createBoolMenuItem(
        "Wall notes (edge bounce)", "", [=]() { return m->params[Gbloink::EDGE_NOTES_PARAM].getValue() > 0.5f; },
        [=](bool on) { m->params[Gbloink::EDGE_NOTES_PARAM].setValue(on ? 1.f : 0.f); }));
}
