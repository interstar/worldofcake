#include "GbloinkControlRunner.h"
#include <cmath>
#include <algorithm>
namespace worldofcake::bridge
{
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
                // The new epoch starts now: anchor to the current host time rather
                // than replaying everything since the host's clock began.
                hostClockBaseTime = hostTime;
                logicalTime = 0.0;
                // A host transport epoch is not an explicit user resume. Preserve
                // the model's pause latch across stop/start and seek boundaries.
                harness->resetTransport();
            }
            const double targetTime = std::max(0.0, hostTime - hostClockBaseTime);
            if (std::isfinite(targetTime) && targetTime > logicalTime) {
                // The host publishes a point ahead of its current audio block. The
                // model splits the step into its own physics resolution, so a large
                // block cannot tunnel a ball through a narrow obstacle.
                harness->advanceTime(targetTime - logicalTime);
                logicalTime = targetTime;
                currentStage = 4;
                drainEvents();
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
    void GbloinkControlRunner::applyAppCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.x, c.y);
        else if (c.kind == CommandKind::setValue)
            harness->setValue(c.controlId, c.value);
    }
    void GbloinkControlRunner::drainEvents()
    {
        while (harness->hasEventBefore(logicalTime)) {
            PreparedEvent e;
            // Model time restarts at each transport epoch; hosts schedule on their own
            // clock, so publish host time (base is 0 when no host clock is used).
            e.timestamp = hostClockBaseTime + harness->nextEventTimestamp();
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
        n.collisionModelTime = harness->logicalTime();
        n.collisionEpoch = harness->collisionEpoch();
        n.collisionCount = std::min(32, harness->collisionCount());
        for (int i = 0; i < n.collisionCount; ++i) {
            auto& cue = n.collisions[i];
            cue.serial = harness->collisionSerial(i);
            cue.time = harness->collisionTime(i);
            cue.x = harness->collisionX(i);
            cue.y = harness->collisionY(i);
            cue.velocity = harness->collisionVelocity(i);
            cue.colour = harness->collisionColour(i);
            cue.kind = harness->collisionKind(i);
            cue.blockId = harness->collisionBlockId(i);
        }
        for (int i = 0; i < 3; i++) {
            n.balls[i].x = harness->ballX(i);
            n.balls[i].y = harness->ballY(i);
            n.balls[i].radius = harness->ballRadius(i);
            n.balls[i].colour = harness->ballColour(i);
            n.ballSpeeds[i] = harness->ballSpeed(i);
            n.ballNoteVelocities[i] = harness->ballNoteVelocity(i);
        }
        auto count = harness->blockCount();
        n.blocks.reserve((size_t)count);
        for (int i = 0; i < count; i++) {
            GbloinkBlockSnapshot b;
            b.id = harness->blockId(i);
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
        n.noteLength = harness->noteLength();
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
