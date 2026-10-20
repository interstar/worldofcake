#include "GoldenpondControlRunner.h"
#include "WorldOfCakeControlIds.h"
#include <algorithm>
#include <cmath>

namespace worldofcake::bridge {
namespace ControlIds = worldofcake::control::goldenpond;
GoldenpondControlRunner::~GoldenpondControlRunner() { stop(); }
void GoldenpondControlRunner::pump(double delta) {
    if (!modelCreated) createModel();
    applyPendingCommands();
    const bool forceSnapshot = snapshotRequested.exchange(false, std::memory_order_acq_rel);
    harness->servicePendingCompile(delta);
    if (hostClockEnabled.load(std::memory_order_acquire)) {
        harness->setTransportRunning(hostTransportRunning.load(std::memory_order_acquire));
        const auto hostBpm = hostTransportBpm.load(std::memory_order_acquire);
        if (std::isfinite(hostBpm) && hostBpm > 0.0)
            harness->setHostBpm(hostBpm);
        const auto epoch = hostTransportEpoch.load(std::memory_order_acquire);
        const double hostTime = hostTransportTime.load(std::memory_order_acquire);
        if (epoch != observedHostTransportEpoch) {
            observedHostTransportEpoch = epoch;
            hostClockBaseTime = hostTime;
            hostClockBaseLogicalTime = 0.0;
            logicalTime = 0.0;
            harness->resetTransportPreservingState();
        }
        const double targetTime = hostClockBaseLogicalTime + std::max(0.0, hostTime - hostClockBaseTime);
        if (std::isfinite(targetTime) && targetTime > logicalTime) {
            harness->resyncTime(targetTime);
            logicalTime = targetTime;
            drainEvents();
        }
    } else if (std::isfinite(delta) && delta > 0) {
        harness->advanceTime(delta);
        logicalTime += delta;
        drainEvents();
    }
    (void)forceSnapshot;
    publishVisualSnapshot();
    persistence.service([this] { return harness->exportStateJson().utf8_str(); }, [this](const std::string& s) {
        harness->importStateJson(::String(s.c_str()));
        logicalTime = harness->logicalTime();
        hostClockBaseLogicalTime = logicalTime;
        hostClockBaseTime = hostTransportTime.load(std::memory_order_acquire);
        observedHostTransportEpoch = hostTransportEpoch.load(std::memory_order_acquire);
        drainEvents();
        publishVisualSnapshot();
    });
}
bool GoldenpondControlRunner::popPreparedEvent(PreparedEvent& event) noexcept {
    if (!events.pop(event)) return false;
    popped.fetch_add(1, std::memory_order_relaxed);
    return true;
}
GoldenpondVisualSnapshot GoldenpondControlRunner::latestVisualSnapshot() const {
    std::lock_guard<std::mutex> lock(snapshotMutex);
    return snapshot;
}
void GoldenpondControlRunner::createModel() { if (!modelCreated) { harness = GoldenpondHarness_obj::__new(); modelCreated = true; logicalTime = 0; drainEvents(); publishVisualSnapshot(); } }
void GoldenpondControlRunner::destroyModel() { if (modelCreated) { harness->destroy(); harness = nullptr; modelCreated = false; } }
void GoldenpondControlRunner::applyCommand(const ControlCommand& c) {
    if (c.kind == CommandKind::textSubmitted) {
        harness->textSubmitted(c.controlId, ::String(c.text));
        return;
    }
    if (c.kind != CommandKind::setValue) return;
    if (c.controlId == ControlIds::kReset) { harness->reset(); logicalTime = 0.0; }
    else if (c.controlId == ControlIds::kPause) harness->setPaused(c.value > .5);
    else harness->setValue(c.controlId, c.value);
}
void GoldenpondControlRunner::publishVisualSnapshot() {
    GoldenpondVisualSnapshot next;
    next.generation = nextGeneration++;
    next.stateRevision = static_cast<std::uint64_t>(harness->stateRevision());
    next.modelReady = harness->modelReady();
    next.logicalTime = logicalTime;
    next.positionTicks = harness->positionTicks();
    next.loopLengthTicks = harness->loopLengthTicks();
    next.bpm = harness->bpm();
    for (int i = 0; i < 4; ++i) {
        next.octaves[static_cast<std::size_t>(i)] = harness->partOctave(i);
        next.velocities[static_cast<std::size_t>(i)] = harness->partVelocity(i);
    }
    next.paused = harness->paused();
    next.muted = harness->muted();
    next.chordInput = harness->chordInput().utf8_str();
    for (int i = 0; i < 4; ++i) next.rhythmInputs[i] = harness->rhythmInput(i).utf8_str();
    next.notes.reserve(static_cast<std::size_t>(harness->noteCount()));
    for (int i = 0; i < harness->noteCount(); ++i) {
        GoldenpondNoteSnapshot note;
        note.partId = harness->notePart(i);
        note.pitch = harness->notePitch(i);
        note.velocity = harness->noteVelocity(i);
        note.startTick = harness->noteStart(i);
        note.durationTicks = harness->noteDuration(i);
        next.notes.push_back(note);
    }
    const int key = harness->correctionKey(logicalTime);
    if (key >= 0 && correctionKey != key) {
        const auto neutral = harness->correctionTable(logicalTime);
        const auto directional = harness->bidirectionalCorrectionTable(logicalTime);
        if (neutral != null() && neutral->length == 128 && directional != null() && directional->length == 256) {
            for (int note = 0; note < 128; ++note) {
                correctionMap[static_cast<std::size_t>(note)].store(neutral->__get(note), std::memory_order_relaxed);
                correctionMap[static_cast<std::size_t>(128 + note)].store(directional->__get(note), std::memory_order_relaxed);
                correctionMap[static_cast<std::size_t>(256 + note)].store(directional->__get(128 + note), std::memory_order_relaxed);
            }
            correctionKey = key;
            correctionRefreshes.fetch_add(1, std::memory_order_relaxed);
        }
    }
    std::lock_guard<std::mutex> lock(snapshotMutex);
    snapshot = std::move(next);
}
void GoldenpondControlRunner::drainEvents() {
    while (harness->hasEventBefore(logicalTime)) {
        PreparedEvent e; e.timestamp = harness->nextEventTimestamp(); e.type = harness->nextEventType();
        e.transportEpoch = observedHostTransportEpoch;
        e.channel = harness->nextEventChannel(); e.data2 = harness->nextEventData2(); e.data3 = harness->nextEventData3();
        if (!events.push(e)) eventDrops++;
        else produced.fetch_add(1, std::memory_order_relaxed);
        harness->popEvent();
    }
}
}
