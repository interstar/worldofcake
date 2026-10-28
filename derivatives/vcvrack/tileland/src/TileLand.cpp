#include "TileLand.hpp"
#include "plugin.hpp"
#include <WocRackParamSync.hpp>
#include <WocRackTiming.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/tileland/TileLandRackLayoutGenerated.h>
#include <worldofcake/generated/rack/tileland/TileLandRackOutputsGenerated.h>
#include <worldofcake/generated/tileland/TilelandControlMetadataGenerated.h>
#include <GLFW/glfw3.h>
#include <asset.hpp>
#include <componentlibrary.hpp>
#include <widget/OpaqueWidget.hpp>
#include <algorithm>
#include <chrono>
using namespace rack::widget;
using namespace rack::app;
namespace
{
    // The model's world (apps/tileland/app.edn :model); the play area shows all of it.
    constexpr float W = worldofcake::metadata::tileland::model::kWorldWidth, H = worldofcake::metadata::tileland::model::kWorldHeight;
    namespace rackLayout = worldofcake::rack::tileland;
    namespace ControlIds = worldofcake::control::tileland;
    NVGcolor rgb(int c)
    {
        return nvgRGB((c >> 16) & 255, (c >> 8) & 255, c & 255);
    }
    void tile(NVGcontext* v, float x, float y, float w, float h, int t)
    {
        float mx = x + w / 2, my = y + h / 2;
        nvgStrokeColor(v, nvgRGBA(255, 255, 255, 215));
        nvgStrokeWidth(v, 1.35);
        nvgBeginPath(v);
        nvgMoveTo(v, mx, y);
        nvgQuadTo(v, mx, my, t ? x : x + w, my);
        nvgStroke(v);
        nvgBeginPath(v);
        nvgMoveTo(v, mx, y + h);
        nvgQuadTo(v, mx, my, t ? x + w : x, my);
        nvgStroke(v);
    }
    struct Play : OpaqueWidget
    {
        TileLand* module = nullptr;
        void onButton(const ButtonEvent& e) override
        {
            if (module && e.button == GLFW_MOUSE_BUTTON_LEFT && e.action == GLFW_PRESS) {
                const float x = std::max(0.f, std::min(box.size.x, e.pos.x));
                const float y = std::max(0.f, std::min(box.size.y, e.pos.y));
                module->playAreaClick(x / box.size.x * W, y / box.size.y * H);
                e.consume(this);
                return;
            }
            OpaqueWidget::onButton(e);
        }
        void draw(const DrawArgs& a) override
        {
            nvgBeginPath(a.vg);
            nvgRect(a.vg, 0, 0, box.size.x, box.size.y);
            nvgFillColor(a.vg, nvgRGB(12, 14, 20));
            nvgFill(a.vg);
            if (module) {
                auto s = module->runner->latestVisualSnapshot();
                nvgSave(a.vg);
                nvgScissor(a.vg, 0, 0, box.size.x, box.size.y);
                if (s.cols && s.rows) {
                    float w = box.size.x / s.cols, h = box.size.y / s.rows;
                    for (int r = 0; r < s.rows; ++r)
                        for (int c = 0; c < s.cols; ++c)
                            tile(a.vg, c * w, r * h, w, h, s.tileTypes[(size_t)(r * s.cols + c)]);
                }
                for (auto& q : s.cursors) {
                    nvgBeginPath(a.vg);
                    nvgCircle(a.vg, q.x / W * box.size.x, q.y / H * box.size.y, std::max(2.5f, 5.f / W * box.size.x));
                    nvgFillColor(a.vg, rgb(q.colour));
                    nvgFill(a.vg);
                }
                nvgRestore(a.vg);
            }
            OpaqueWidget::draw(a);
        }
    };
} // namespace
TileLand::TileLand()
{
    config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
    const auto speeds = std::array<const worldofcake::metadata::tileland::Knob*, 3>{
        &worldofcake::metadata::tileland::kRedspeed,
        &worldofcake::metadata::tileland::kGreenspeed,
        &worldofcake::metadata::tileland::kBluespeed};
    for (int i = 0; i < 3; ++i) {
        const auto* speed = speeds[static_cast<std::size_t>(i)];
        configParam(SPEED_CURSOR1_PARAM + i, 0.f, 1.f,
                    static_cast<float>((speed->defaultValue - speed->minimum) / (speed->maximum - speed->minimum)),
                    "Cursor " + std::to_string(i + 1) + " speed");
    }
    configParam(SIM_RATE_PARAM, 0, 1, .5, "Display rate");
    configButton(RESET_PARAM, "Reset");
    configSwitch(PAUSE_PARAM, 0, 1, 0, "Pause", {"Run", "Pause"});
    for (int i = 0; i < worldofcake::rack::tileland::kOutputCount; ++i)
        configOutput(i, worldofcake::rack::tileland::kOutputLabels[i]);
    int seed = (int)std::chrono::high_resolution_clock::now().time_since_epoch().count();
    runner.reset(new worldofcake::bridge::TileLandControlRunner(seed));
    runner->start(worldofcake::rack::kControlPeriodSeconds);
}
TileLand::~TileLand()
{
    if (runner)
        runner->stop();
}
void TileLand::playAreaClick(float x, float y)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::playAreaClick;
    c.sequence = guiSequence++;
    c.x = x;
    c.y = y;
    runner->enqueueGuiCommand(c);
}
void TileLand::send(int id, double v)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::setValue;
    c.sequence = hostSequence++;
    c.controlId = id;
    c.value = v;
    runner->enqueueHostCommand(c);
}
void TileLand::process(const ProcessArgs&)
{
    const auto speeds = std::array<const worldofcake::metadata::tileland::Knob*, 3>{
        &worldofcake::metadata::tileland::kRedspeed,
        &worldofcake::metadata::tileland::kGreenspeed,
        &worldofcake::metadata::tileland::kBluespeed};
    for (int i = 0; i < ControlIds::kSpeedCount; ++i)
        worldofcake::rack::syncControlValue(
            worldofcake::metadata::tileland::denormalize(*speeds[static_cast<std::size_t>(i)], params[SPEED_CURSOR1_PARAM + i].getValue()),
            lastSpeed[i], 1e-5, ControlIds::speedUid(i), [this](int id, double value) { send(id, value); });
    worldofcake::rack::syncTransport(params[PAUSE_PARAM].getValue(), lastPause, params[RESET_PARAM].getValue(),
                                     lastReset, [this](const worldofcake::bridge::ControlCommand& c) { runner->enqueueHostCommand(c); });
    worldofcake::bridge::TileLandControlSnapshot s;
    while (runner->popControlSnapshot(s))
        for (int i = 0; i < 6; ++i)
            cvV[i] = worldofcake::rack::midi7ToUnipolar10V(s.values[i]);
    for (int i = 0; i < 6; ++i)
        outputs[CV_CH1_X_OUTPUT + i].setVoltage(cvV[i]);
}
TileLandWidget::TileLandWidget(TileLand* m)
{
    setModule(m);
    setPanel(createPanel(asset::plugin(pluginInstance, "generated/TileLand.svg")));
    addChild(createWidget<ScrewSilver>({RACK_GRID_WIDTH, 0}));
    addChild(createWidget<ScrewSilver>({box.size.x - 2 * RACK_GRID_WIDTH, 0}));
    auto* p = new Play;
    p->module = m;
    // Everything is placed by the generated layout (apps/tileland/rack.layla); its text is in the panel SVG.
    p->box.pos = mm2px(Vec(rackLayout::kPlayarea.x, rackLayout::kPlayarea.y));
    p->box.size = mm2px(Vec(rackLayout::kPlayarea.width, rackLayout::kPlayarea.height));
    addChild(p);
    const auto at = [](rackLayout::RackPoint q) { return mm2px(Vec(q.x, q.y)); };
    addParam(createParamCentered<Rogan2PSRed>(at(rackLayout::kRedspeedCenter), m, TileLand::SPEED_CURSOR1_PARAM));
    addParam(createParamCentered<Rogan2PSGreen>(at(rackLayout::kGreenspeedCenter), m, TileLand::SPEED_CURSOR2_PARAM));
    addParam(createParamCentered<Rogan2PSBlue>(at(rackLayout::kBluespeedCenter), m, TileLand::SPEED_CURSOR3_PARAM));
    // SIM_RATE_PARAM stays configured for saved patches but has no knob: nothing reads it.
    addParam(createParamCentered<LEDButton>(at(rackLayout::kResetCenter), m, TileLand::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(at(rackLayout::kPauseCenter), m, TileLand::PAUSE_PARAM));
    static_assert(rackLayout::kLayoutOutputCount == TileLand::NUM_OUTPUTS, "one patch-bay socket per output");
    for (int i = 0; i < rackLayout::kLayoutOutputCount; ++i)
        addOutput(createOutputCentered<PJ301MPort>(at(rackLayout::kOutputPositions[i]), m, TileLand::CV_CH1_X_OUTPUT + i));
}
