#include "GbloinkControlRunner.h"
#include "WorldOfCakeControlIds.h"
#include <cmath>
namespace worldofcake::bridge
{
    namespace ControlIds = worldofcake::control::gbloink;
    GbloinkControlRunner::GbloinkControlRunner(double w, double h, int seed)
        : modelWidth(w), modelHeight(h), modelSeed(seed)
    {
    }
    GbloinkControlRunner::~GbloinkControlRunner()
    {
        stop();
        destroyModel();
    }
    void GbloinkControlRunner::pump(double delta)
    {
        controlTickCount++;
        currentStage = 1;
        if (!modelCreated)
            createModel();
        currentStage = 2;
        persistence.service([this] { return harness->exportStateJson().utf8_str(); },
                            [this](const std::string& s) {
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                drainEvents();
                                publishVisualSnapshot();
                            });
        currentStage = 3;
        applyPendingCommands();
        currentStage = 4;
        if (std::isfinite(delta) && delta > 0) {
            harness->advanceTime(delta);
            logicalTime += delta;
            currentStage = 5;
            drainEvents();
        }
        currentStage = 6;
        publishVisualSnapshot();
        currentStage = 7;
        persistence.service([this] { return harness->exportStateJson().utf8_str(); },
                            [this](const std::string& s) {
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                drainEvents();
                                publishVisualSnapshot();
                            });
        currentStage = 8;
    }
    bool GbloinkControlRunner::popPreparedEvent(PreparedEvent& e) noexcept
    {
        return events.pop(e);
    }
    GbloinkVisualSnapshot GbloinkControlRunner::latestVisualSnapshot() const
    {
        std::lock_guard<std::mutex> l(snapshotMutex);
        return snapshot;
    }
    void GbloinkControlRunner::applyCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.x, c.y);
        else if (c.kind == CommandKind::setValue) {
            if (c.controlId == ControlIds::kReset)
                harness->reset();
            else if (c.controlId == ControlIds::kPause)
                harness->setPaused(c.value > .5);
            else
                harness->setValue(c.controlId, c.value);
        }
    }
    void GbloinkControlRunner::drainEvents()
    {
        while (harness->hasEventBefore(logicalTime)) {
            PreparedEvent e;
            e.timestamp = harness->nextEventTimestamp();
            e.type = harness->nextEventType();
            e.channel = harness->nextEventChannel();
            e.data2 = harness->nextEventData2();
            e.data3 = harness->nextEventData3();
            if (!events.push(e))
                eventDrops++;
            harness->popEvent();
        }
    }
    void GbloinkControlRunner::publishVisualSnapshot()
    {
        GbloinkVisualSnapshot n;
        n.generation = nextGeneration++;
        n.logicalTime = logicalTime;
        for (int i = 0; i < 3; i++) {
            n.balls[i].x = harness->ballX(i);
            n.balls[i].y = harness->ballY(i);
            n.balls[i].radius = harness->ballRadius(i);
            n.balls[i].colour = harness->ballColour(i);
        }
        auto count = harness->blockCount();
        n.blocks.reserve((size_t)count);
        for (int i = 0; i < count; i++) {
            GbloinkBlockSnapshot b;
            b.left = harness->blockLeft(i);
            b.top = harness->blockTop(i);
            b.right = harness->blockRight(i);
            b.bottom = harness->blockBottom(i);
            b.colour = harness->blockColour(i);
            n.blocks.push_back(b);
        }
        n.paused = harness->paused();
        n.edgeNotes = harness->edgeNotes();
        n.scaleIndex = harness->scaleIndex();
        std::lock_guard<std::mutex> l(snapshotMutex);
        snapshot = std::move(n);
    }
    void GbloinkControlRunner::createModel()
    {
        if (modelCreated)
            return;
        harness = GbloinkHarness_obj::__new(modelWidth, modelHeight, modelSeed);
        modelCreated = true;
        logicalTime = 0;
        publishVisualSnapshot();
    }
    void GbloinkControlRunner::destroyModel()
    {
        if (!modelCreated)
            return;
        harness->destroy();
        harness = nullptr;
        modelCreated = false;
    }
} // namespace worldofcake::bridge
