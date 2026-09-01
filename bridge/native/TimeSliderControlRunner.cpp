#include "TimeSliderControlRunner.h"
#include <cmath>
namespace worldofcake::bridge
{
    TimeSliderControlRunner::TimeSliderControlRunner(int w, int h, double slow, double fast)
        : modelWidth(w), modelHeight(h), modelSlow(slow), modelFast(fast)
    {
    }
    TimeSliderControlRunner::~TimeSliderControlRunner()
    {
        stop();
        destroyModel();
    }
    void TimeSliderControlRunner::pump(double d)
    {
        if (!modelCreated)
            createModel();
        persistence.service([this] { return harness->exportStateJson().utf8_str(); },
                            [this](const std::string& s) {
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                publishSnapshot();
                            });
        applyPendingCommands();
        if (std::isfinite(d) && d > 0) {
            harness->advanceTime(d);
            logicalTime += d;
        }
        publishSnapshot();
    }
    bool TimeSliderControlRunner::popControlSnapshot(TimeSliderControlSnapshot& v) noexcept
    {
        return controlSnapshots.pop(v);
    }
    TimeSliderControlSnapshot TimeSliderControlRunner::latestVisualSnapshot() const
    {
        std::lock_guard<std::mutex> l(visualMutex);
        return visualSnapshot;
    }
    void TimeSliderControlRunner::applyCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.x, c.y);
        else if (c.kind == CommandKind::setValue && c.controlId == 20)
            harness->reset();
        else if (c.kind == CommandKind::setValue && c.controlId == 21)
            harness->setPaused(c.value > .5);
    }
    TimeSliderControlSnapshot TimeSliderControlRunner::captureSnapshot()
    {
        TimeSliderControlSnapshot n;
        n.generation = nextGeneration++;
        n.logicalTime = logicalTime;
        n.paused = harness->paused();
        for (int i = 0; i < 4; i++) {
            auto& s = n.sliders[i];
            s.x = harness->sliderX(i);
            s.y = harness->sliderY(i);
            s.width = harness->sliderWidth(i);
            s.height = harness->sliderHeight(i);
            s.current = harness->sliderCurrent(i);
            s.destination = harness->sliderDestination(i);
            s.midiValue = harness->sliderMidiValue(i);
        }
        return n;
    }
    void TimeSliderControlRunner::publishSnapshot()
    {
        auto n = captureSnapshot();
        if (!controlSnapshots.push(n))
            snapshotDrops++;
        std::lock_guard<std::mutex> l(visualMutex);
        visualSnapshot = n;
    }
    void TimeSliderControlRunner::createModel()
    {
        if (modelCreated)
            return;
        harness = TimeSliderHarness_obj::__new(modelWidth, modelHeight, modelSlow, modelFast);
        modelCreated = true;
        logicalTime = 0;
        publishSnapshot();
    }
    void TimeSliderControlRunner::destroyModel()
    {
        if (!modelCreated)
            return;
        harness->destroy();
        harness = nullptr;
        modelCreated = false;
    }
} // namespace worldofcake::bridge
