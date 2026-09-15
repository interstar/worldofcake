#include "KDiagramControlRunner.h"
#include "WorldOfCakeControlIds.h"
#include <algorithm>
#include <cmath>

namespace worldofcake::bridge
{
    namespace ControlIds = worldofcake::control::kdiagram;
    KDiagramControlRunner::KDiagramControlRunner(int seed) : modelSeed(seed)
    {
    }
    KDiagramControlRunner::~KDiagramControlRunner()
    {
        stop();
        destroyModel();
    }
    void KDiagramControlRunner::pump(double d)
    {
        if (!modelCreated)
            createModel();
        persistence.service([this] { return harness->exportStateJson().utf8_str(); },
                            [this](const std::string& s) {
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                drainEvents();
                                publishSnapshots();
                            });
        applyPendingCommands();
        if (std::isfinite(d) && d > 0) {
            harness->advanceTime(d);
            logicalTime += d;
            drainEvents();
        }
        publishSnapshots();
    }
    bool KDiagramControlRunner::popPreparedEvent(PreparedEvent& e) noexcept
    {
        return events.pop(e);
    }
    bool KDiagramControlRunner::popControlSnapshot(KDiagramControlSnapshot& s) noexcept
    {
        return controls.pop(s);
    }
    KDiagramVisualSnapshot KDiagramControlRunner::latestVisualSnapshot() const
    {
        std::lock_guard<std::mutex> l(visualMutex);
        return visual;
    }
    void KDiagramControlRunner::applyCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.x, c.y);
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kReset)
            harness->reset();
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kPause)
            harness->setPaused(c.value > .5);
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kRotateLeft)
            harness->rotate(-.12);
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kRotateRight)
            harness->rotate(.12);
        else if (c.kind == CommandKind::setValue)
            harness->setValue(c.controlId, c.value);
    }
    void KDiagramControlRunner::drainEvents()
    {
        while (harness->hasEventBefore(logicalTime)) {
            PreparedEvent e;
            e.timestamp = harness->eventTimestamp();
            e.type = harness->eventType();
            e.channel = harness->eventChannel();
            e.data2 = harness->eventData2();
            e.data3 = harness->eventData3();
            if (!events.push(e))
                eventDrops++;
            harness->popEvent();
        }
    }
    void KDiagramControlRunner::publishSnapshots()
    {
        auto g = nextGeneration++;
        KDiagramControlSnapshot c;
        c.generation = g;
        c.logicalTime = logicalTime;
        for (int i = 0; i < 3; i++) {
            c.values[i * 2] = std::max(0, std::min(127, (int)((harness->cursorX(i) + 1) * .5 * 127)));
            c.values[i * 2 + 1] = std::max(0, std::min(127, (int)((harness->cursorY(i) + 1) * .5 * 127)));
        }
        if (!controls.push(c))
            snapshotDrops++;
        KDiagramVisualSnapshot n;
        n.generation = g;
        n.logicalTime = logicalTime;
        n.paused = harness->paused();
        n.radius = harness->radius();
        n.selectedCursor = harness->selected();
        n.scaleIndex = harness->scaleIndex();
        auto nc = harness->nodeCount();
        n.nodes.reserve((size_t)nc);
        for (int i = 0; i < nc; i++) {
            KDiagramNodeSnapshot q;
            q.x = harness->nodeX(i);
            q.y = harness->nodeY(i);
            n.nodes.push_back(q);
            for (int a = 0; a < harness->nodeArcCount(i); a++) {
                KDiagramArcSnapshot ar;
                ar.source = i;
                ar.destination = harness->arcDestination(i, a);
                n.arcs.push_back(ar);
            }
        }
        for (int i = 0; i < 3; i++) {
            auto& q = n.cursors[i];
            q.x = harness->cursorX(i);
            q.y = harness->cursorY(i);
            q.targetX = harness->cursorTargetX(i);
            q.targetY = harness->cursorTargetY(i);
            q.speed = harness->cursorSpeed(i);
            q.colour = harness->cursorColour(i);
            q.channel = harness->cursorChannel(i);
            q.moving = harness->cursorMoving(i);
        }
        std::lock_guard<std::mutex> l(visualMutex);
        visual = std::move(n);
    }
    void KDiagramControlRunner::createModel()
    {
        if (modelCreated)
            return;
        harness = KDiagramHarness_obj::__new(modelSeed);
        modelCreated = true;
        logicalTime = 0;
        publishSnapshots();
    }
    void KDiagramControlRunner::destroyModel()
    {
        if (!modelCreated)
            return;
        harness->destroy();
        harness = nullptr;
        modelCreated = false;
    }
} // namespace worldofcake::bridge
