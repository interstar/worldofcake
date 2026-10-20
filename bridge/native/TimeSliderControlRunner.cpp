#include "TimeSliderControlRunner.h"
#include "WorldOfCakeControlIds.h"
#include "worldofcake/generated/timeslider/TimeSliderControlIdsGenerated.h"
#include <cmath>
namespace worldofcake::bridge
{
    namespace ControlIds = worldofcake::control::timeslider;
    TimeSliderControlRunner::TimeSliderControlRunner(int w, int h, double slow, double fast)
        : modelWidth(w), modelHeight(h), modelSlow(slow), modelFast(fast)
    {
    }
    TimeSliderControlRunner::~TimeSliderControlRunner()
    {
        stop();
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
        const double step = std::isfinite(d) && d > 0 ? d : 0.001;
        if (step > 0) {
            harness->advanceTime(step);
            logicalTime += step;
            drainEvents();
        }
        publishSnapshot();
    }
    bool TimeSliderControlRunner::popControlSnapshot(TimeSliderControlSnapshot& v) noexcept
    {
        return controlSnapshots.pop(v);
    }
    bool TimeSliderControlRunner::popPreparedEvent(PreparedEvent& v) noexcept
    {
        return events.pop(v);
    }
    TimeSliderControlSnapshot TimeSliderControlRunner::latestVisualSnapshot() const
    {
        std::lock_guard<std::mutex> l(visualMutex);
        return visualSnapshot;
    }
    void TimeSliderControlRunner::applyCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.controlId, c.x, c.y);
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kReset)
            harness->reset();
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kPause)
            harness->setPaused(c.value > .5);
    }
    TimeSliderControlSnapshot TimeSliderControlRunner::captureSnapshot()
    {
        TimeSliderControlSnapshot n;
        n.generation = nextGeneration++;
        n.modelReady = harness->modelReady();
        n.stateRevision = static_cast<std::uint64_t>(harness->stateRevision());
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
    void TimeSliderControlRunner::drainEvents()
    {
        while (harness->hasEventBefore(logicalTime)) {
            PreparedEvent e;
            e.timestamp = harness->nextEventTimestamp();
            e.transportEpoch = 0;
            e.type = harness->nextEventType();
            e.channel = harness->nextEventChannel();
            e.data2 = harness->nextEventData2();
            e.data3 = harness->nextEventData3();
            if (!events.push(e))
                eventDrops++;
            harness->popEvent();
        }
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
