#include "Zewp.hpp"
#include "plugin.hpp"
#include <WocRackParamSync.hpp>
#include <WocRackTiming.hpp>
#include <WocRackStateJson.hpp>
#include <WocRackTransport.hpp>
#include <WocRackVoltage.hpp>
#include <GLFW/glfw3.h>
#include <asset.hpp>
#include <componentlibrary.hpp>
#include <widget/OpaqueWidget.hpp>
#include <widget/ZoomWidget.hpp>
#include <chrono>
#include <cmath>
#include <WorldOfCakeBridgeTypes.h>
#include <WorldOfCakeControlIds.h>
#include <worldofcake/generated/rack/zewp/ZewpRackOutputsGenerated.h>
#include <worldofcake/generated/rack/zewp/ZewpRackLayoutGenerated.h>
#include <worldofcake/generated/zewp/ZewpControlMetadataGenerated.h>
using namespace rack::widget;
using namespace rack::app;
namespace
{
    // The model's world (apps/zewp/app.edn :model); the play area shows all of it.
    constexpr float W = worldofcake::metadata::zewp::model::kWorldWidth, H = worldofcake::metadata::zewp::model::kWorldHeight;
    namespace ControlIds = worldofcake::control::zewp;
    worldofcake::LocalPoint toLocal(worldofcake::PanelPoint p, float w, float h)
    {
        worldofcake::CoordinateMapper m(worldofcake::PanelPoint(0, 0), worldofcake::PanelPoint(w, h),
                                        worldofcake::LocalPoint(0, 0), worldofcake::LocalPoint(W, H));
        auto q = m.forward(p.x, p.y);
        return worldofcake::LocalPoint(q.x, q.y);
    }
    struct Play : OpaqueWidget
    {
        ZewpModule* m = nullptr;
        Vec hoverPos;
        bool dragging = false;
        void onHover(const HoverEvent& e) override
        {
            hoverPos = e.pos;
            Widget::onHover(e);
        }
        void onButton(const ButtonEvent& e) override
        {
            Widget::onButton(e);
            if (!m || e.button != GLFW_MOUSE_BUTTON_LEFT)
                return;
            if (e.action == GLFW_PRESS) {
                hoverPos = e.pos;
                dragging = true;
                auto p = toLocal(worldofcake::PanelPoint(e.pos.x, e.pos.y), box.size.x, box.size.y);
                m->click(p.x, p.y);
            } else if (e.action == GLFW_RELEASE) {
                dragging = false;
                auto p = toLocal(worldofcake::PanelPoint(hoverPos.x, hoverPos.y), box.size.x, box.size.y);
                m->release(p.x, p.y);
            }
            e.consume(this);
        }
        void onDragStart(const DragStartEvent& e) override
        {
            Widget::onDragStart(e);
            if (m && e.button == GLFW_MOUSE_BUTTON_LEFT && !e.isConsumed()) {
                dragging = true;
                e.consume(this);
            }
        }
        void onDragMove(const DragMoveEvent& e) override
        {
            auto* zoomWidget = getAncestorOfType<ZoomWidget>();
            float zoom = zoomWidget ? zoomWidget->zoom : 1.f;
            Vec delta = e.mouseDelta;
            if (zoom > 0.f)
                delta = delta.div(zoom);
            if (m && dragging && box.size.x > 0 && box.size.y > 0) {
                hoverPos = hoverPos.plus(delta);
                auto p = toLocal(worldofcake::PanelPoint(hoverPos.x, hoverPos.y), box.size.x, box.size.y);
                m->drag(p.x, p.y);
                e.consume(this);
            }
        }
        void onDragEnd(const DragEndEvent& e) override
        {
            dragging = false;
            if (m) {
                auto p = toLocal(worldofcake::PanelPoint(hoverPos.x, hoverPos.y), box.size.x, box.size.y);
                m->release(p.x, p.y);
                e.consume(this);
            }
        }
        void draw(const DrawArgs& a) override
        {
            nvgBeginPath(a.vg);
            nvgRect(a.vg, 0, 0, box.size.x, box.size.y);
            nvgFillColor(a.vg, nvgRGB(0, 0, 0));
            nvgFill(a.vg);
            if (!m) {
                OpaqueWidget::draw(a);
                return;
            }
            auto s = m->runner->latestVisualSnapshot();
            nvgSave(a.vg);
            nvgScissor(a.vg, 0, 0, box.size.x, box.size.y);
            for (auto& b : s.blocks) {
                float x = b.x / W * box.size.x, y = b.y / H * box.size.y, w = b.width / W * box.size.x,
                      h = b.height / H * box.size.y;
                nvgBeginPath(a.vg);
                nvgRect(a.vg, x - w / 2, y - h / 2, w, h);
                nvgFillColor(a.vg, nvgRGB(240, 240, 240));
                nvgFill(a.vg);
            }
            for (auto& z : s.agents) {
                float x = z.x / W * box.size.x, y = z.y / H * box.size.y,
                      dx = std::cos(z.angle) * z.length / W * box.size.x,
                      dy = std::sin(z.angle) * z.length / W * box.size.x;
                nvgBeginPath(a.vg);
                nvgMoveTo(a.vg, x - dx, y - dy);
                nvgLineTo(a.vg, x + dx, y + dy);
                nvgStrokeColor(a.vg, nvgRGB((z.colour >> 16) & 255, (z.colour >> 8) & 255, z.colour & 255));
                nvgStrokeWidth(a.vg, 2);
                nvgStroke(a.vg);
            }
            nvgRestore(a.vg);
            OpaqueWidget::draw(a);
        }
    };
} // namespace
ZewpModule::ZewpModule()
{
    config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
    configParam(POPULATION_PARAM, 0, 40, 10, "Zewps");
    configParam(SPEED_PARAM, 1.0 / 3.0, 1.5, 1.0, "Speed");
    configButton(RESET_PARAM, "Reset");
    configSwitch(PAUSE_PARAM, 0, 1, 0, "Pause", {"Run", "Pause"});
    for (int i = 0; i < worldofcake::rack::zewp::kOutputCount; ++i)
        configOutput(i, worldofcake::rack::zewp::kOutputLabels[i]);
    int seed = (int)std::chrono::high_resolution_clock::now().time_since_epoch().count();
    runner.reset(new worldofcake::bridge::ZewpControlRunner(seed));
    runner->start(worldofcake::rack::kControlPeriodSeconds);
}
ZewpModule::~ZewpModule()
{
    if (runner)
        runner->stop();
}
void ZewpModule::click(float x, float y)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::playAreaClick;
    c.sequence = guiSequence++;
    c.x = x;
    c.y = y;
    runner->enqueueGuiCommand(c);
}
void ZewpModule::drag(float x, float y)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::playAreaDrag;
    c.sequence = guiSequence++;
    c.x = x;
    c.y = y;
    runner->enqueueGuiCommand(c);
}
void ZewpModule::release(float x, float y)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::playAreaRelease;
    c.sequence = guiSequence++;
    c.x = x;
    c.y = y;
    runner->enqueueGuiCommand(c);
}
void ZewpModule::send(int id, double v)
{
    worldofcake::bridge::ControlCommand c;
    c.kind = worldofcake::bridge::CommandKind::setValue;
    c.sequence = hostSequence++;
    c.controlId = id;
    c.value = v;
    runner->enqueueHostCommand(c);
}
void ZewpModule::process(const ProcessArgs&)
{
    worldofcake::rack::syncControlValue(params[POPULATION_PARAM].getValue(), lastPop, .01, ControlIds::kPopulation,
                                        [this](int id, double value) { send(id, value); });
    worldofcake::rack::syncControlValue(params[SPEED_PARAM].getValue(), lastSpeed, 1e-5, ControlIds::kSpeed,
                                        [this](int id, double value) { send(id, value); });
    worldofcake::rack::syncTransport(params[PAUSE_PARAM].getValue(), lastPause, params[RESET_PARAM].getValue(),
                                     lastReset, [this](const worldofcake::bridge::ControlCommand& c) { runner->enqueueHostCommand(c); });
    worldofcake::bridge::ZewpControlSnapshot snap;
    while (runner->popControlSnapshot(snap))
        for (int i = 0; i < 18; ++i)
            cv[i] = snap.values[i];
    for (int i = 0; i < 6; ++i) {
        outputs[X1_OUTPUT + 3 * i].setVoltage(worldofcake::rack::midi7ToUnipolar10V(cv[3 * i]));
        outputs[Y1_OUTPUT + 3 * i].setVoltage(worldofcake::rack::midi7ToUnipolar10V(127 - cv[3 * i + 1]));
        outputs[GATE1_OUTPUT + 3 * i].setVoltage(worldofcake::rack::gate10V(cv[3 * i + 2] > 0));
    }
}
json_t* ZewpModule::dataToJson()
{
    return worldofcake::rack::makeStateJson(runner->exportStateJson());
}
void ZewpModule::dataFromJson(json_t* j)
{
    auto state = worldofcake::rack::readStateJson(j);
    if (state.empty())
        return;
    runner->importStateJson(state);
    const auto snap = runner->latestVisualSnapshot();
    params[POPULATION_PARAM].setValue((float)snap.population);
    lastPop = (float)snap.population;
    params[SPEED_PARAM].setValue((float)snap.speedMultiplier);
    lastSpeed = (float)snap.speedMultiplier;
    params[PAUSE_PARAM].setValue(snap.paused ? 1.f : 0.f);
    lastPause = snap.paused ? 1 : 0;
    lastReset = 0.f;
}
ZewpWidget::ZewpWidget(ZewpModule* m)
{
    setModule(m);
    setPanel(createPanel(asset::plugin(pluginInstance, "generated/Zewp.svg")));
    addChild(createWidget<ScrewSilver>({RACK_GRID_WIDTH, 0}));
    addChild(createWidget<ScrewSilver>({box.size.x - 2 * RACK_GRID_WIDTH, 0}));
    auto* p = new Play;
    p->m = m;
    p->box.pos = mm2px(math::Vec(worldofcake::rack::zewp::kPlayarea.x, worldofcake::rack::zewp::kPlayarea.y));
    p->box.size = mm2px(math::Vec(worldofcake::rack::zewp::kPlayarea.width, worldofcake::rack::zewp::kPlayarea.height));
    addChild(p);
    addParam(createParamCentered<RoundBlackKnob>(mm2px(math::Vec(worldofcake::rack::zewp::kPopulationCenter.x, worldofcake::rack::zewp::kPopulationCenter.y)), m, ZewpModule::POPULATION_PARAM));
    addParam(createParamCentered<RoundBlackKnob>(mm2px(math::Vec(worldofcake::rack::zewp::kSpeedCenter.x, worldofcake::rack::zewp::kSpeedCenter.y)), m, ZewpModule::SPEED_PARAM));
    addParam(createParamCentered<LEDButton>(mm2px(math::Vec(worldofcake::rack::zewp::kResetCenter.x, worldofcake::rack::zewp::kResetCenter.y)), m, ZewpModule::RESET_PARAM));
    addParam(createParamCentered<VCVLatch>(mm2px(math::Vec(worldofcake::rack::zewp::kPauseCenter.x, worldofcake::rack::zewp::kPauseCenter.y)), m, ZewpModule::PAUSE_PARAM));
    for (int i = 0; i < 6; ++i) {
        const auto* outputPositions = worldofcake::rack::zewp::kOutputPositions + 3 * i;
        addOutput(createOutputCentered<PJ301MPort>(mm2px(math::Vec(outputPositions[0].x, outputPositions[0].y)), m, ZewpModule::X1_OUTPUT + 3 * i));
        addOutput(createOutputCentered<PJ301MPort>(mm2px(math::Vec(outputPositions[1].x, outputPositions[1].y)), m, ZewpModule::Y1_OUTPUT + 3 * i));
        addOutput(createOutputCentered<PJ301MPort>(mm2px(math::Vec(outputPositions[2].x, outputPositions[2].y)), m, ZewpModule::GATE1_OUTPUT + 3 * i));
    }
}
