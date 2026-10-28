#include "Gbloink.hpp"
#include "GbloinkTrails.hpp"
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
    const auto kVelocityParameters = std::array<const worldofcake::metadata::gbloink::Knob*, 3>{
        &worldofcake::metadata::gbloink::kRedvelocity,
        &worldofcake::metadata::gbloink::kGreenvelocity,
        &worldofcake::metadata::gbloink::kBluevelocity};
    const int kGateOutputs[3] = {Gbloink::GATE_BALL1_OUTPUT, Gbloink::GATE_BALL2_OUTPUT, Gbloink::GATE_BALL3_OUTPUT};
    const int kPitchOutputs[3] = {Gbloink::PITCH_BALL1_OUTPUT, Gbloink::PITCH_BALL2_OUTPUT, Gbloink::PITCH_BALL3_OUTPUT};
    const int kVelocityOutputs[3] = {Gbloink::VELOCITY_BALL1_OUTPUT, Gbloink::VELOCITY_BALL2_OUTPUT,
                                     Gbloink::VELOCITY_BALL3_OUTPUT};
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
        worldofcake::bridge::GbloinkVisualSnapshot visualSnapshot;
        std::shared_ptr<GbloinkTrailSettings> settings;
        GbloinkTrailWidget* trails;
        struct Ripple {
            worldofcake::bridge::GbloinkCollisionCue cue;
            double born = 0;
        };
        std::array<Ripple, 32> ripples{};
        int rippleCount = 0, lastCollisionSerial = 0;
        std::uint64_t rippleRevision = 0;
        double previousCollisionTime = -1;
        int rippleEpoch = -1;
        bool loggedFirstCue = false, loggedFirstRing = false;

        static double wallSeconds() {
            return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
        }

        void updateRipples() {
            const double now = wallSeconds();
            if (rippleEpoch != visualSnapshot.collisionEpoch || rippleRevision != visualSnapshot.stateRevision || visualSnapshot.collisionModelTime < previousCollisionTime) {
                rippleCount = lastCollisionSerial = 0;
            }
            rippleEpoch = visualSnapshot.collisionEpoch;
            rippleRevision = visualSnapshot.stateRevision;
            previousCollisionTime = visualSnapshot.collisionModelTime;
            int keep = 0;
            for (int i = 0; i < rippleCount; ++i)
                if (now-ripples[i].born < (ripples[i].cue.kind == 1 && settings->blockFlashes ? 1.8 : 0.7)) ripples[keep++] = ripples[i];
            rippleCount = keep;
            if (visualSnapshot.muted) rippleCount = 0;
            for (int i = 0; i < visualSnapshot.collisionCount; ++i) {
                const auto& cue = visualSnapshot.collisions[i];
                if (cue.serial <= lastCollisionSerial) continue;
                lastCollisionSerial = cue.serial;
                if (visualSnapshot.muted) continue;
                const double age = std::max(0.0, visualSnapshot.collisionModelTime-cue.time);
                const bool flash = cue.kind == 1 && settings->blockFlashes;
                if ((!settings->collisionRipples && !flash) || age >= (flash ? 1.8 : 0.7)) continue;
                if (rippleCount == static_cast<int>(ripples.size())) {
                    for (int j = 1; j < rippleCount; ++j) ripples[j-1] = ripples[j];
                    --rippleCount;
                }
                auto& ripple = ripples[rippleCount++];
                ripple.cue = cue;
                ripple.born = now-age;
                if (!loggedFirstCue) {
                    INFO("Gbloink ripples: accepted cue serial=%d kind=%d velocity=%d age=%.4f", cue.serial, cue.kind, cue.velocity, age);
                    loggedFirstCue = true;
                }
            }
            if (!settings->collisionRipples && !settings->blockFlashes) rippleCount = 0;
        }

        int blockAlpha(int id) const {
            if (!settings->blockFlashes) return 200;
            const double now = wallSeconds();
            double boost = 0;
            for (int i = 0; i < rippleCount; ++i) {
                if (ripples[i].cue.blockId != id) continue;
                const double age = now-ripples[i].born;
                boost = std::max(boost,std::min(1.0,std::max(0.0,(1.8-age)/0.3)));
            }
            return static_cast<int>(200+55*boost);
        }

        void drawRipples(NVGcontext* vg) {
            if (!settings->collisionRipples) return;
            const double now = wallSeconds();
            float transform[6];
            nvgCurrentTransform(vg, transform);
            const float minimumStroke = 1.5f/std::max(0.01f,std::abs(transform[0]));
            for (int i = 0; i < rippleCount; ++i) {
                const auto& ripple = ripples[i];
                const auto& cue = ripple.cue;
                const float maxRadius = 96.f * cue.velocity / 127.f;
                const bool pair = cue.kind == 2;
                NVGcolor colour = nvgRgbPacked(cue.colour);
                if (pair) {
                    colour.r += (1.f-colour.r)*0.25f;
                    colour.g += (1.f-colour.g)*0.25f;
                    colour.b += (1.f-colour.b)*0.25f;
                }
                for (int ring = 0; ring < 3; ++ring) {
                    const float phase = static_cast<float>((now-ripple.born-ring*0.064)/0.56);
                    if (phase <= 0.f || phase >= 1.f) continue;
                    const float radius = maxRadius * phase;
                    // Remain visible while expanding, then fade over the last 40%.
                    colour.a = (pair ? 0.9f : 0.65f)*std::min(1.f,(1.f-phase)*2.5f);
                    nvgBeginPath(vg);
                    nvgEllipse(vg, cue.x/kLocalW*box.size.x, cue.y/kLocalH*box.size.y,
                        radius/kLocalW*box.size.x, radius/kLocalH*box.size.y);
                    nvgStrokeWidth(vg, std::max(minimumStroke, (pair ? 2.4f : 2.f)*box.size.x/kLocalW));
                    nvgStrokeColor(vg, colour);
                    nvgStroke(vg);
                    if (!loggedFirstRing) {
                        INFO("Gbloink ripples: submitted ring radius=%.2f alpha=%.3f zoom=%.3f", radius, colour.a, transform[0]);
                        loggedFirstRing = true;
                    }
                }
            }
        }

        explicit GbloinkPlayWidget(std::shared_ptr<GbloinkTrailSettings> s) : settings(std::move(s)) {
            trails = new GbloinkTrailWidget(settings);
            trails->snapshot = &visualSnapshot;
            addChild(trails);
        }

        void step() override {
            if (module && module->runner) visualSnapshot = module->runner->latestVisualSnapshot();
            updateRipples();
            trails->box.size = box.size;
            trails->visible = module && settings->enabled && !trails->failed();
            OpaqueWidget::step();
        }

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

            // Rack composites the history child before the sharp current scene.
            OpaqueWidget::draw(args);
            const auto& snapshot = visualSnapshot;

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
                nvgFillColor(vg, nvgTransRGBA(nvgRGB(r, g, b), blockAlpha(block.id)));
                nvgFill(vg);
            }

            // Rings sit above obstacles so a block cannot hide its own impact.
            drawRipples(vg);
            nvgRestore(vg);

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
    const auto& noteLength = worldofcake::metadata::gbloink::kNote_length;
    configParam(NOTE_LENGTH_PARAM, 0.f, 1.f,
                static_cast<float>(worldofcake::metadata::gbloink::normalize(noteLength, noteLength.defaultValue)),
                noteLength.label);
    for (int i = 0; i < 3; i++) {
        const auto* velocity = kVelocityParameters[static_cast<std::size_t>(i)];
        configParam(VELOCITY_BALL1_PARAM + i, static_cast<float>(velocity->minimum),
                    static_cast<float>(velocity->maximum), static_cast<float>(velocity->defaultValue), velocity->label);
        paramQuantities[VELOCITY_BALL1_PARAM + i]->snapEnabled = true;
    }
    for (int i = 0; i < worldofcake::rack::gbloink::kOutputCount; i++) {
        configOutput(i, worldofcake::rack::gbloink::kOutputLabels[i]);
    }

    const auto seed = static_cast<int>(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    runner.reset(new worldofcake::bridge::GbloinkControlRunner(kLocalW, kLocalH, seed));
    runner->start(worldofcake::rack::kControlPeriodSeconds);
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
    for (int i = 0; i < 3; i++) {
        const auto send = [this](int id, double value) { enqueueHostValue(id, value); };
        const auto* speed = kSpeedParameters[static_cast<std::size_t>(i)];
        worldofcake::rack::syncControlValue(
            worldofcake::metadata::gbloink::denormalize(*speed, params[SPEED_BALL1_PARAM + i].getValue()),
            lastSpeed[i], 1e-5, ControlIds::speedUid(i), send);
        worldofcake::rack::syncControlValue(params[VELOCITY_BALL1_PARAM + i].getValue(), lastVelocity[i], 0.5,
                                            ControlIds::noteVelocityUid(i), send);
    }
    worldofcake::rack::syncControlValue(
        worldofcake::metadata::gbloink::denormalize(worldofcake::metadata::gbloink::kNote_length,
                                                    params[NOTE_LENGTH_PARAM].getValue()),
        lastNoteLength, 1e-6, ControlIds::kNoteLength, [this](int id, double value) { enqueueHostValue(id, value); });
    const auto enqueueHost = [this](const worldofcake::bridge::ControlCommand& c) { runner->enqueueHostCommand(c); };
    worldofcake::rack::syncLifecycleLatch(params[PAUSE_PARAM].getValue(), lastPause, worldofcake::bridge::pauseCommand,
                                          enqueueHost);
    worldofcake::rack::syncLifecycleLatch(params[MUTE_PARAM].getValue(), lastMute, worldofcake::bridge::muteCommand,
                                          enqueueHost);
    const float resetValue = params[RESET_PARAM].getValue();
    if (ignoreResetUntilReleased) {
        lastResetButton = resetValue;
        if (resetValue <= 0.5f)
            ignoreResetUntilReleased = false;
        else
            params[RESET_PARAM].setValue(0.f);
    } else if (worldofcake::rack::risingEdge(resetValue, lastResetButton)) {
        enqueueHost(worldofcake::bridge::resetCommand());
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
    // The runner releases events when model time reaches them, so they are due
    // on arrival. Ball channels are 1..3; each gate follows its sounding notes.
    worldofcake::bridge::PreparedEvent event;
    int safetyPops = 0;
    while (safetyPops++ < 256 && runner->popPreparedEvent(event))
        notes.schedule(0.0, event);
    notes.emitDue(0.0, [this](double, const worldofcake::bridge::PreparedEvent& e) {
        const int bi = e.channel - 1;
        if (e.type == worldofcake::bridge::NoteOutputScheduler::kNoteOn && bi >= 0 && bi < 3) {
            pitchV[bi] = worldofcake::rack::midiNoteToOneVoltPerOctave(e.data2);
            velocityV[bi] = worldofcake::rack::midi7ToUnipolar10V(e.data3);
        }
    });

    for (int i = 0; i < 3; i++) {
        const bool gate = gates[i].process(notes.soundingNotes(i + 1), notes.noteOnCount(i + 1), args.sampleTime);
        outputs[kGateOutputs[i]].setVoltage(worldofcake::rack::gate10V(gate));
        outputs[kPitchOutputs[i]].setVoltage(pitchV[i]);
        outputs[kVelocityOutputs[i]].setVoltage(velocityV[i]);
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
    params[MUTE_PARAM].setValue(snapshot.muted ? 1.f : 0.f);
    lastMute = snapshot.muted ? 1 : 0;
    params[SCALE_PARAM].setValue(static_cast<float>(snapshot.scaleIndex));
    lastScaleIdx = snapshot.scaleIndex;
    params[EDGE_NOTES_PARAM].setValue(snapshot.edgeNotes ? 1.f : 0.f);
    lastEdgeNotes = snapshot.edgeNotes ? 1 : 0;
    params[NOTE_LENGTH_PARAM].setValue(static_cast<float>(
        worldofcake::metadata::gbloink::normalize(worldofcake::metadata::gbloink::kNote_length, snapshot.noteLength)));
    lastNoteLength = static_cast<float>(snapshot.noteLength);
    for (int i = 0; i < 3; i++) {
        params[VELOCITY_BALL1_PARAM + i].setValue(static_cast<float>(snapshot.ballNoteVelocities[i]));
        lastVelocity[i] = static_cast<float>(snapshot.ballNoteVelocities[i]);
    }
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

    trailSettings = std::make_shared<GbloinkTrailSettings>();
    auto* play = new GbloinkPlayWidget(trailSettings);
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
    const RackPoint& redVelocity = worldofcake::rack::gbloink::kRedvelocityCenter;
    const RackPoint& greenVelocity = worldofcake::rack::gbloink::kGreenvelocityCenter;
    const RackPoint& blueVelocity = worldofcake::rack::gbloink::kBluevelocityCenter;
    addParam(createParamCentered<Rogan1PSRed>(mm2px(math::Vec(redVelocity.x, redVelocity.y)), module,
                                              Gbloink::VELOCITY_BALL1_PARAM));
    addParam(createParamCentered<Rogan1PSGreen>(mm2px(math::Vec(greenVelocity.x, greenVelocity.y)), module,
                                                Gbloink::VELOCITY_BALL2_PARAM));
    addParam(createParamCentered<Rogan1PSBlue>(mm2px(math::Vec(blueVelocity.x, blueVelocity.y)), module,
                                               Gbloink::VELOCITY_BALL3_PARAM));
    const RackPoint& scale = worldofcake::rack::gbloink::kScaleselectCenter;
    const RackPoint& edge = worldofcake::rack::gbloink::kEdgeNotesCenter;
    const RackPoint& reset = worldofcake::rack::gbloink::kResetCenter;
    const RackPoint& pause = worldofcake::rack::gbloink::kPauseCenter;
    addParam(createParamCentered<RoundBlackSnapKnob>(mm2px(math::Vec(scale.x, scale.y)), module, Gbloink::SCALE_PARAM));
    addParam(createParamCentered<CKSS>(mm2px(math::Vec(edge.x, edge.y)), module, Gbloink::EDGE_NOTES_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px(math::Vec(reset.x, reset.y)), module, Gbloink::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px(math::Vec(pause.x, pause.y)), module, Gbloink::PAUSE_PARAM));
    const RackPoint& noteLength = worldofcake::rack::gbloink::kNoteLengthCenter;
    addParam(createParamCentered<RoundBlackKnob>(mm2px(math::Vec(noteLength.x, noteLength.y)), module,
                                                 Gbloink::NOTE_LENGTH_PARAM));
    const auto& mute = worldofcake::rack::gbloink::kMuteCenter;
    addParam(createParamCentered<VCVLatch>(mm2px(math::Vec(mute.x, mute.y)), module, Gbloink::MUTE_PARAM));

    // Generated Rack output order: per ball (red, green, blue): gate, pitch, velocity.
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
    const auto visuals = trailSettings;
    menu->addChild(createBoolMenuItem("Block impact flashes", "",
        [visuals]() { return visuals->blockFlashes; }, [visuals](bool on) { visuals->blockFlashes = on; }));
    menu->addChild(createBoolMenuItem("Collision ripples", "",
        [visuals]() { return visuals->collisionRipples; }, [visuals](bool on) { visuals->collisionRipples = on; }));
    menu->addChild(createBoolMenuItem("GPU ball trails (experimental)", "",
        [visuals]() { return visuals->enabled; }, [visuals](bool on) { visuals->enabled = on; }));
    menu->addChild(createBoolMenuItem("Trails: half resolution", "",
        [visuals]() { return visuals->halfResolution; }, [visuals](bool on) { visuals->halfResolution = on; }));
    menu->addChild(createBoolMenuItem("Trail timing in Rack log", "",
        [visuals]() { return visuals->diagnostics; }, [visuals](bool on) { visuals->diagnostics = on; }));
    menu->addChild(createMenuItem("Trails: short (0.1 s half-life)", "", [visuals]() { visuals->halfLife = 0.1f; }));
    menu->addChild(createMenuItem("Trails: medium (0.22 s half-life)", "", [visuals]() { visuals->halfLife = 0.22f; }));
    menu->addChild(createMenuItem("Trails: long (0.6 s half-life)", "", [visuals]() { visuals->halfLife = 0.6f; }));
    menu->addChild(createBoolMenuItem(
        "Wall notes (edge bounce)", "", [=]() { return m->params[Gbloink::EDGE_NOTES_PARAM].getValue() > 0.5f; },
        [=](bool on) { m->params[Gbloink::EDGE_NOTES_PARAM].setValue(on ? 1.f : 0.f); }));
}
