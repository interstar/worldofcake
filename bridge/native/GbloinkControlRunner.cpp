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
    }
    void GbloinkControlRunner::pump(double delta)
    {
        controlTickCount++;
        currentStage = 1;
        if (!modelCreated)
            createModel();
        currentStage = 2;
        applyPendingCommands();
        currentStage = 3;
        // A stopped DAW transport is a hard generation boundary for Gbloink.
        // Discard any events already prepared for the stopped epoch and do not
        // advance the Haxe simulation until the host explicitly resumes.
        if (!hostTransportRunning.load(std::memory_order_acquire)) {
            PreparedEvent discarded;
            while (events.pop(discarded)) {
                eventDrops++;
            }
            publishVisualSnapshot();
            currentStage = 7;
            return;
        }
        if (hostClockEnabled.load(std::memory_order_acquire)) {
            const auto epoch = hostTransportEpoch.load(std::memory_order_acquire);
            const double hostTime = hostTransportTime.load(std::memory_order_acquire);
            if (epoch != observedHostTransportEpoch) {
                observedHostTransportEpoch = epoch;
                hostClockBaseTime = 0.0;
                logicalTime = 0.0;
                // A host transport epoch is not an explicit user resume. Preserve
                // the model's pause latch across stop/start and seek boundaries.
                harness->resetTransportPreservingState();
            }
            const double targetTime = std::max(0.0, hostTime - hostClockBaseTime);
            if (std::isfinite(targetTime) && targetTime > logicalTime) {
                // The host publishes a point ahead of its current audio block. Keep
                // the physics resolution independent of the host buffer size so a
                // large block cannot tunnel a ball through a narrow obstacle.
                constexpr double maxSimulationStep = 0.001;
                while (logicalTime + maxSimulationStep < targetTime) {
                    harness->advanceTime(maxSimulationStep);
                    logicalTime += maxSimulationStep;
                    currentStage = 4;
                    drainEvents();
                }
                const double remainder = targetTime - logicalTime;
                if (remainder > 0.0) {
                    harness->advanceTime(remainder);
                    logicalTime = targetTime;
                    currentStage = 4;
                    drainEvents();
                }
            }
        } else if (std::isfinite(delta) && delta > 0) {
            harness->advanceTime(delta);
            logicalTime += delta;
            currentStage = 4;
            drainEvents();
        }
        currentStage = 5;
        publishVisualSnapshot();
        currentStage = 6;
        persistence.service([this] { return harness->exportStateJson().utf8_str(); },
                            [this](const std::string& s) {
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                drainEvents();
                                publishVisualSnapshot();
                            });
        currentStage = 7;
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
            e.transportEpoch = observedHostTransportEpoch;
            e.type = harness->nextEventType();
            e.channel = harness->nextEventChannel();
            e.data2 = harness->nextEventData2();
            e.data3 = harness->nextEventData3();
            if (!events.push(e))
                eventDrops++;
            else
                preparedEvents++;
            harness->popEvent();
        }
    }
    void GbloinkControlRunner::publishVisualSnapshot()
    {
        GbloinkVisualSnapshot n;
        n.generation = nextGeneration++;
        n.modelReady = harness->modelReady();
        n.stateRevision = static_cast<std::uint64_t>(harness->stateRevision());
        n.logicalTime = logicalTime;
        for (int i = 0; i < 3; i++) {
            n.balls[i].x = harness->ballX(i);
            n.balls[i].y = harness->ballY(i);
            n.balls[i].radius = harness->ballRadius(i);
            n.balls[i].colour = harness->ballColour(i);
            n.ballSpeeds[i] = harness->ballSpeed(i);
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
        n.muted = harness->muted();
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
