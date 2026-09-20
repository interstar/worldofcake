#include "GoldenpondControlRunner.h"
#include "WorldOfCakeControlIds.h"
#include <cmath>

namespace worldofcake::bridge {
namespace ControlIds = worldofcake::control::goldenpond;
GoldenpondControlRunner::~GoldenpondControlRunner() { stop(); destroyModel(); }
void GoldenpondControlRunner::pump(double delta) {
    if (!modelCreated) createModel();
    applyPendingCommands();
    harness->servicePendingCompile(delta);
    publishVisualSnapshot();
    if (std::isfinite(delta) && delta > 0) { harness->advanceTime(delta); logicalTime += delta; drainEvents(); }
    publishVisualSnapshot();
    persistence.service([this] { return harness->exportStateJson().utf8_str(); }, [this](const std::string& s) {
        harness->importStateJson(::String(s.c_str())); logicalTime = harness->logicalTime(); drainEvents(); publishVisualSnapshot(); });
}
bool GoldenpondControlRunner::popPreparedEvent(PreparedEvent& event) noexcept { return events.pop(event); }
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
    if (c.controlId == ControlIds::kReset) harness->reset();
    else if (c.controlId == ControlIds::kPause) harness->setPaused(c.value > .5);
    else harness->setValue(c.controlId, c.value);
}
void GoldenpondControlRunner::publishVisualSnapshot() {
    GoldenpondVisualSnapshot next;
    next.generation = nextGeneration++;
    next.logicalTime = logicalTime;
    next.positionTicks = harness->positionTicks();
    next.loopLengthTicks = harness->loopLengthTicks();
    next.paused = harness->paused();
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
    const int revision = harness->correctionRevision();
    const int chordIndex = harness->correctionChordIndex(logicalTime);
    if (correctionRevision != revision || correctionChordIndex != chordIndex) {
        const auto table = harness->correctionTable(logicalTime);
        if (table != null() && table->length == 128) {
            for (int note = 0; note < 128; ++note)
                correctionMap[static_cast<std::size_t>(note)].store(table->__get(note), std::memory_order_relaxed);
            correctionRevision = revision;
            correctionChordIndex = chordIndex;
            correctionRefreshes.fetch_add(1, std::memory_order_relaxed);
        }
    }
    std::lock_guard<std::mutex> lock(snapshotMutex);
    snapshot = std::move(next);
}
void GoldenpondControlRunner::drainEvents() {
    while (harness->hasEventBefore(logicalTime)) {
        PreparedEvent e; e.timestamp = harness->nextEventTimestamp(); e.type = harness->nextEventType();
        e.channel = harness->nextEventChannel(); e.data2 = harness->nextEventData2(); e.data3 = harness->nextEventData3();
        if (!events.push(e)) eventDrops++;
        harness->popEvent();
    }
}
}
