#include "TimeSlider.hpp"
#include "plugin.hpp"
#include <WocRackTiming.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/timeslider/TimeSliderRackLayoutGenerated.h>
#include <worldofcake/generated/rack/timeslider/TimeSliderRackOutputsGenerated.h>
#include <worldofcake/generated/timeslider/TimesliderControlMetadataGenerated.h>
#include <GLFW/glfw3.h>
#include <asset.hpp>
#include <componentlibrary.hpp>
#include <ui/TextField.hpp>
#include <widget/OpaqueWidget.hpp>
#include <cstring>
#include <string>
using namespace rack::widget;
using namespace rack::app;
namespace
{
    // One CV output per lane of Rack's model (`:model :lanes` in apps/timeslider/rack.edn).
    static_assert(TimeSlider::NUM_OUTPUTS == worldofcake::metadata::timeslider::kLaneCount,
                  "Rack TimeSlider needs one CV output per lane");

    /** Gap between lanes, as a fraction of the play area's width. */
    constexpr float kLaneGap = 0.03f;
    /** A lane's colour, from the app's lane palette (red, green, blue, ...). */
    NVGcolor laneColour(std::size_t lane)
    {
        const auto c = static_cast<unsigned>(worldofcake::metadata::timeslider::kLanes[lane].track->colour);
        return nvgRGB((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
    }

    namespace metadata = worldofcake::metadata::timeslider;

    // The lanes are spread evenly across a width; where they go is this panel's choice.
    float laneWidthIn(float total, int lanes)
    {
        return total * (1.0f - kLaneGap * static_cast<float>(lanes - 1)) / static_cast<float>(lanes);
    }
    float laneLeftIn(float total, int lane, int lanes)
    {
        return static_cast<float>(lane) * (laneWidthIn(total, lanes) + kLaneGap * total);
    }

    /**
        A lane's label, above the lane. It shows the model's label and submits edits on Enter or
        when it loses focus; the model saves it with the patch.
    */
    struct LaneLabel : rack::ui::TextField
    {
        TimeSlider* module = nullptr;
        std::size_t lane = 0;
        /** The model's label when last shown, so only model changes overwrite what is typed. */
        std::string shown;

        void step() override
        {
            if (module) {
                const auto s = module->runner->latestVisualSnapshot();
                if (lane < s.sliders.size() && s.sliders[lane].label != shown) {
                    shown = s.sliders[lane].label;
                    if (APP->event->getSelectedWidget() != this)
                        setText(shown);
                }
            }
            TextField::step();
        }
        void commit()
        {
            if (module)
                module->sendText(metadata::kLanes[lane].label->controlId, text);
        }
        void onSelectKey(const SelectKeyEvent& e) override
        {
            if (e.action == GLFW_PRESS && (e.key == GLFW_KEY_ENTER || e.key == GLFW_KEY_KP_ENTER)) {
                commit();
                APP->event->setSelectedWidget(nullptr);
                e.consume(this);
                return;
            }
            TextField::onSelectKey(e);
        }
        void onDeselect(const DeselectEvent& e) override
        {
            commit();
            TextField::onDeselect(e);
        }
    };

    /** The lanes. The model knows only each lane's value, 0 (bottom) .. 1 (top). */
    struct Play : OpaqueWidget
    {
        TimeSlider* module = nullptr;

        float laneWidth(int lanes) const { return laneWidthIn(box.size.x, lanes); }
        float laneLeft(int lane, int lanes) const { return laneLeftIn(box.size.x, lane, lanes); }

        void onButton(const ButtonEvent& e) override
        {
            Widget::onButton(e);
            if (!module || e.button != GLFW_MOUSE_BUTTON_LEFT || e.action != GLFW_PRESS || e.isConsumed())
                return;
            const int lanes = static_cast<int>(module->runner->latestVisualSnapshot().sliders.size());
            for (int i = 0; i < lanes; ++i) {
                const float left = laneLeft(i, lanes), width = laneWidth(lanes);
                if (e.pos.x < left || e.pos.x > left + width)
                    continue;
                // The lane's own space: x is the travel-time fraction, y the target (0 bottom .. 1 top).
                module->trackClick(metadata::kLanes[static_cast<std::size_t>(i)].track->controlId, (e.pos.x - left) / width, 1.0f - e.pos.y / box.size.y);
                e.consume(this);
                return;
            }
        }

        void draw(const DrawArgs& a) override
        {
            nvgBeginPath(a.vg);
            nvgRect(a.vg, 0, 0, box.size.x, box.size.y);
            nvgFillColor(a.vg, nvgRGB(18, 20, 26));
            nvgFill(a.vg);
            if (module) {
                const auto s = module->runner->latestVisualSnapshot();
                const int lanes = static_cast<int>(s.sliders.size());
                nvgSave(a.vg);
                nvgScissor(a.vg, 0, 0, box.size.x, box.size.y);
                for (int i = 0; i < lanes; ++i) {
                    const auto& lane = s.sliders[static_cast<std::size_t>(i)];
                    const NVGcolor colour = laneColour(static_cast<std::size_t>(i));
                    const float x = laneLeft(i, lanes), w = laneWidth(lanes), h = box.size.y;
                    const float valueY = (1.0f - static_cast<float>(lane.value)) * h;
                    nvgBeginPath(a.vg);
                    nvgRect(a.vg, x, 0, w, h);
                    nvgFillColor(a.vg, nvgRGB(40, 43, 50));
                    nvgFill(a.vg);
                    nvgBeginPath(a.vg);
                    nvgRect(a.vg, x, valueY, w, h - valueY);
                    nvgFillColor(a.vg, nvgTransRGBA(colour, 90));
                    nvgFill(a.vg);
                    nvgBeginPath(a.vg);
                    nvgMoveTo(a.vg, x, valueY);
                    nvgLineTo(a.vg, x + w, valueY);
                    nvgStrokeWidth(a.vg, 2);
                    nvgStrokeColor(a.vg, colour);
                    nvgStroke(a.vg);
                    if (lane.moving) {
                        const float targetY = (1.0f - static_cast<float>(lane.target)) * h;
                        nvgBeginPath(a.vg);
                        nvgMoveTo(a.vg, x, targetY);
                        nvgLineTo(a.vg, x + w, targetY);
                        nvgStrokeWidth(a.vg, 1);
                        nvgStrokeColor(a.vg, nvgRGBA(255, 255, 255, 180));
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
    runner.reset(new worldofcake::bridge::TimeSliderControlRunner());
    runner->start(worldofcake::rack::kControlPeriodSeconds);
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
void TimeSlider::sendText(int controlId, const std::string& text)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::textSubmitted;
    c.sequence = guiSequence++;
    c.controlId = controlId;
    std::strncpy(c.text, text.c_str(), sizeof(c.text) - 1);
    c.text[sizeof(c.text) - 1] = '\0';
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
                                     lastReset, [this](const worldofcake::bridge::ControlCommand& c) { runner->enqueueHostCommand(c); });
    // Each lane's control output (0..1, decided in Haxe) as 0..10 V. Rack's model has one lane per CV output.
    for (int i = 0; i < NUM_OUTPUTS; ++i)
        outputs[CV_SLIDER1_OUTPUT + i].setVoltage(10.0f * runner->controlOutputValue(i));
}
TimeSliderWidget::TimeSliderWidget(TimeSlider* m)
{
    setModule(m);
    setPanel(createPanel(asset::plugin(pluginInstance, "generated/TimeSlider.svg")));
    addChild(createWidget<ScrewSilver>({RACK_GRID_WIDTH, 0}));
    addChild(createWidget<ScrewSilver>({box.size.x - 2 * RACK_GRID_WIDTH, 0}));
    // The play area comes from the generated Rack layout (apps/timeslider/rack.layla): a row of
    // lane labels at its top, the lanes below.
    namespace rackLayout = worldofcake::rack::timeslider;
    const float kAreaX = rackLayout::kPlayarea.x, kAreaY = rackLayout::kPlayarea.y;
    const float kAreaWidth = rackLayout::kPlayarea.width, kAreaHeight = rackLayout::kPlayarea.height;
    constexpr float kLabelHeight = 7, kLabelGap = 1;
    const int lanes = static_cast<int>(metadata::kLaneCount);
    for (int i = 0; i < lanes; ++i) {
        auto* label = new LaneLabel;
        label->module = m;
        label->lane = static_cast<std::size_t>(i);
        label->placeholder = "Lane " + std::to_string(i + 1);
        label->box.pos = mm2px(Vec(kAreaX + laneLeftIn(kAreaWidth, i, lanes), kAreaY));
        label->box.size = mm2px(Vec(laneWidthIn(kAreaWidth, lanes), kLabelHeight));
        addChild(label);
    }
    auto* p = new Play;
    p->module = m;
    p->box.pos = mm2px(Vec(kAreaX, kAreaY + kLabelHeight + kLabelGap));
    p->box.size = mm2px(Vec(kAreaWidth, kAreaHeight - kLabelHeight - kLabelGap));
    addChild(p);
    // Reset and pause where rack.layla puts them; their captions are in the panel SVG.
    // SIM_RATE_PARAM stays configured for saved patches but has no knob: nothing reads it.
    addParam(createParamCentered<LEDButton>(mm2px(Vec(rackLayout::kResetCenter.x, rackLayout::kResetCenter.y)), m, TimeSlider::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px(Vec(rackLayout::kPauseCenter.x, rackLayout::kPauseCenter.y)), m, TimeSlider::PAUSE_PARAM));
    static_assert(rackLayout::kLayoutOutputCount == TimeSlider::NUM_OUTPUTS, "one patch-bay socket per lane");
    for (int i = 0; i < rackLayout::kLayoutOutputCount; ++i) {
        const auto at = rackLayout::kOutputPositions[i];
        addOutput(createOutputCentered<PJ301MPort>(mm2px(Vec(at.x, at.y)), m, TimeSlider::CV_SLIDER1_OUTPUT + i));
    }
}
