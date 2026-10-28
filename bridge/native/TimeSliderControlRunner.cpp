#include "TimeSliderControlRunner.h"
#include <cmath>
namespace worldofcake::bridge
{
    TimeSliderControlRunner::TimeSliderControlRunner() = default;
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
    bool TimeSliderControlRunner::popPreparedEvent(PreparedEvent& v) noexcept
    {
        return events.pop(v);
    }
    TimeSliderControlSnapshot TimeSliderControlRunner::latestVisualSnapshot() const
    {
        std::lock_guard<std::mutex> l(visualMutex);
        return visualSnapshot;
    }
    void TimeSliderControlRunner::applyAppCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.controlId, c.x, c.y);
        else if (c.kind == CommandKind::setValue)
            harness->setValue(c.controlId, c.value);
        else if (c.kind == CommandKind::textSubmitted)
            harness->submitText(c.controlId, ::String(c.text));
    }
    TimeSliderControlSnapshot TimeSliderControlRunner::captureSnapshot()
    {
        TimeSliderControlSnapshot n;
        n.generation = nextGeneration++;
        n.modelReady = harness->modelReady();
        n.stateRevision = static_cast<std::uint64_t>(harness->stateRevision());
        n.logicalTime = logicalTime;
        n.paused = harness->paused();
        const int lanes = harness->sliderCount();
        n.sliders.resize(static_cast<std::size_t>(lanes));
        for (int i = 0; i < lanes; i++) {
            auto& s = n.sliders[static_cast<std::size_t>(i)];
            s.value = harness->sliderValue(i);
            s.target = harness->sliderTarget(i);
            s.moving = harness->sliderMoving(i);
            s.channel = harness->sliderChannel(i);
            s.ccNumber = harness->sliderCcNumber(i);
            s.label = harness->sliderLabel(i).utf8_str();
        }
        return n;
    }
    void TimeSliderControlRunner::publishSnapshot()
    {
        auto n = captureSnapshot();
        std::lock_guard<std::mutex> l(visualMutex);
        visualSnapshot = std::move(n);
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
        harness = TimeSliderHarness_obj::__new();
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
