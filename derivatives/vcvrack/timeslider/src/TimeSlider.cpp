#include "TimeSlider.hpp"
#include "plugin.hpp"
#include <WocRackTiming.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/timeslider/TimeSliderRackOutputsGenerated.h>
#include <worldofcake/generated/timeslider/TimeSliderControlIdsGenerated.h>
#include <GLFW/glfw3.h>
#include <asset.hpp>
#include <componentlibrary.hpp>
#include <widget/OpaqueWidget.hpp>
using namespace rack::widget;
using namespace rack::app;
namespace
{
    constexpr float W = 800.f, H = 600.f;
    namespace ControlIds = worldofcake::control::timeslider;
    constexpr worldofcake::rack::TransportControlIds kTransportIds{ControlIds::kReset, ControlIds::kPause};
    constexpr int kTrackControlIds[4] = {ControlIds::kCc1track, ControlIds::kCc2track, ControlIds::kCc3track,
                                         ControlIds::kCc4track};
    struct Play : OpaqueWidget
    {
        TimeSlider* module = nullptr;
        void onButton(const ButtonEvent& e) override
        {
            Widget::onButton(e);
            if (module && e.button == GLFW_MOUSE_BUTTON_LEFT && e.action == GLFW_PRESS && !e.isConsumed()) {
                const auto snapshot = module->runner->latestVisualSnapshot();
                const float modelX = e.pos.x / box.size.x * W;
                const float modelY = e.pos.y / box.size.y * H;
                for (int i = 0; i < 4; ++i) {
                    const auto& track = snapshot.sliders[i];
                    if (modelX >= track.x && modelX <= track.x + track.width && modelY >= track.y &&
                        modelY <= track.y + track.height) {
                        module->trackClick(kTrackControlIds[i], modelX - track.x, modelY - track.y);
                        e.consume(this);
                        return;
                    }
                }
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
                for (auto& q : s.sliders) {
                    float x = q.x / W * box.size.x, y = q.y / H * box.size.y, w = q.width / W * box.size.x,
                          h = q.height / H * box.size.y;
                    nvgBeginPath(a.vg);
                    nvgRect(a.vg, x, y, w, h);
                    nvgFillColor(a.vg, nvgRGB(50, 50, 50));
                    nvgFill(a.vg);
                    for (int j = 0; j < 2; ++j) {
                        float yy = y + (j ? q.destination : q.current) / H * box.size.y;
                        nvgBeginPath(a.vg);
                        nvgMoveTo(a.vg, x, yy);
                        nvgLineTo(a.vg, x + w, yy);
                        nvgStrokeWidth(a.vg, 2);
                        nvgStrokeColor(a.vg, j ? nvgRGB(255, 255, 0) : nvgRGB(0, 255, 0));
                        nvgStroke(a.vg);
                    }
                }
                nvgRestore(a.vg);
            }
            OpaqueWidget::draw(a);
        }
    };
} // namespace
TimeSlider::TimeSlider()
{
    config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
    configParam(SIM_RATE_PARAM, 0, 1, .5, "Display rate");
    configButton(RESET_PARAM, "Reset");
    configSwitch(PAUSE_PARAM, 0, 1, 0, "Pause", {"Run", "Pause"});
    for (int i = 0; i < worldofcake::rack::timeslider::kOutputCount; ++i)
        configOutput(i, worldofcake::rack::timeslider::kOutputLabels[i]);
    runner.reset(new worldofcake::bridge::TimeSliderControlRunner((int)W, (int)H, 120, .5));
    runner->start(worldofcake::rack::kControlPeriodSeconds, worldofcake::rack::kLogicalDeltaSeconds);
}
TimeSlider::~TimeSlider()
{
    if (runner)
        runner->stop();
}
void TimeSlider::trackClick(int uid, float x, float y)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::playAreaClick;
    c.sequence = guiSequence++;
    c.controlId = uid;
    c.x = x;
    c.y = y;
    runner->enqueueGuiCommand(c);
}
void TimeSlider::enqueueHostValue(int id, double v)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::setValue;
    c.sequence = hostSequence++;
    c.controlId = id;
    c.value = v;
    runner->enqueueHostCommand(c);
}
void TimeSlider::process(const ProcessArgs&)
{
    worldofcake::rack::syncTransport(params[PAUSE_PARAM].getValue(), lastPause, params[RESET_PARAM].getValue(),
                                     lastReset, kTransportIds, [this](int id, double v) { enqueueHostValue(id, v); });
    worldofcake::bridge::TimeSliderControlSnapshot s;
    while (runner->popControlSnapshot(s))
        for (int i = 0; i < 4; ++i)
            cvV[i] = worldofcake::rack::midi7ToUnipolar10V(s.sliders[i].midiValue);
    for (int i = 0; i < 4; ++i)
        outputs[CV_SLIDER1_OUTPUT + i].setVoltage(cvV[i]);
}
TimeSliderWidget::TimeSliderWidget(TimeSlider* m)
{
    setModule(m);
    setPanel(createPanel(asset::plugin(pluginInstance, "generated/TimeSlider.svg")));
    addChild(createWidget<ScrewSilver>({RACK_GRID_WIDTH, 0}));
    addChild(createWidget<ScrewSilver>({box.size.x - 2 * RACK_GRID_WIDTH, 0}));
    auto* p = new Play;
    p->module = m;
    p->box.pos = mm2px({22, 18});
    p->box.size = mm2px({88, 95});
    addChild(p);
    addParam(createParamCentered<RoundBlackKnob>(mm2px({10, 110}), m, TimeSlider::SIM_RATE_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px({10, 122}), m, TimeSlider::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px({24, 122}), m, TimeSlider::PAUSE_PARAM));
    float ys[4] = {26, 46, 66, 86};
    for (int i = 0; i < 4; ++i)
        addOutput(createOutputCentered<PJ301MPort>(mm2px({123, ys[i]}), m, TimeSlider::CV_SLIDER1_OUTPUT + i));
}
