#include "KDiagramControlRunner.h"
#include "WorldOfCakeControlIds.h"
#include <algorithm>
#include <chrono>
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
    }
    void KDiagramControlRunner::pump(double d)
    {
        pumpStartCount.fetch_add(1, std::memory_order_relaxed);
        if (!modelCreated)
            createModel();
        setDiagnosticStage(DiagnosticStage::persistence);
        persistence.service([this] {
                                setDiagnosticStage(DiagnosticStage::exportState);
                                auto state = harness->exportStateJson().utf8_str();
                                setDiagnosticStage(DiagnosticStage::persistence);
                                return state;
                            },
                            [this](const std::string& s) {
                                setDiagnosticStage(DiagnosticStage::importState);
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                drainEvents();
                                publishSnapshots();
                                setDiagnosticStage(DiagnosticStage::persistence);
                            });
        setDiagnosticStage(DiagnosticStage::applyCommands);
        applyPendingCommands();
        // A DAW's stopped transport stops the model (and releases its notes); Rack never stops it.
        harness->setTransportRunning(hostTransportRunning.load(std::memory_order_acquire));
        if (std::isfinite(d) && d > 0) {
            setDiagnosticStage(DiagnosticStage::advanceTime);
            harness->advanceTime(d);
            logicalTime += d;
            drainEvents();
        }
        publishSnapshots();
        pumpCompletionCount.fetch_add(1, std::memory_order_relaxed);
        lastCompletedPumpMs.store(monotonicMilliseconds(), std::memory_order_relaxed);
        setDiagnosticStage(DiagnosticStage::idle);
    }
    bool KDiagramControlRunner::popPreparedEvent(PreparedEvent& e) noexcept
    {
        return events.pop(e);
    }
    KDiagramVisualSnapshot KDiagramControlRunner::latestVisualSnapshot() const
    {
        std::lock_guard<std::mutex> l(visualMutex);
        return visual;
    }
    void KDiagramControlRunner::applyAppCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.x, c.y);
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kRotateLeft)
            harness->rotate(-.12);
        else if (c.kind == CommandKind::setValue && c.controlId == ControlIds::kRotateRight)
            harness->rotate(.12);
        else if (c.kind == CommandKind::setValue)
            harness->setValue(c.controlId, c.value);
    }
    void KDiagramControlRunner::drainEvents()
    {
        setDiagnosticStage(DiagnosticStage::drainEvents);
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
        KDiagramVisualSnapshot n;
        n.generation = g;
        n.modelReady = harness->modelReady();
        n.stateRevision = static_cast<std::uint64_t>(harness->stateRevision());
        n.logicalTime = logicalTime;
        n.paused = harness->paused();
        n.radius = harness->radius();
        n.selectedCursor = harness->selected();
        n.scaleIndex = harness->scaleIndex();
        n.noteLength = harness->noteLength();
        setDiagnosticStage(DiagnosticStage::graphSnapshot);
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
        setDiagnosticStage(DiagnosticStage::cursorSnapshot);
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
        setDiagnosticStage(DiagnosticStage::publishVisual);
        std::lock_guard<std::mutex> l(visualMutex);
        visual = std::move(n);
    }
    void KDiagramControlRunner::createModel()
    {
        if (modelCreated)
            return;
        setDiagnosticStage(DiagnosticStage::createModel);
        harness = KDiagramHarness_obj::__new(modelSeed);
        modelCreated = true;
        logicalTime = 0;
        publishSnapshots();
    }
    void KDiagramControlRunner::destroyModel()
    {
        if (!modelCreated)
            return;
        setDiagnosticStage(DiagnosticStage::destroyModel);
        harness->destroy();
        harness = nullptr;
        modelCreated = false;
        setDiagnosticStage(DiagnosticStage::idle);
    }
    std::uint64_t KDiagramControlRunner::monotonicMilliseconds() noexcept
    {
        using namespace std::chrono;
        return static_cast<std::uint64_t>(duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
    }
    void KDiagramControlRunner::setDiagnosticStage(DiagnosticStage stage) noexcept
    {
        stageEnteredMs.store(monotonicMilliseconds(), std::memory_order_relaxed);
        currentStage.store(static_cast<int>(stage), std::memory_order_release);
    }
    std::uint64_t KDiagramControlRunner::diagnosticStageAgeMs() const noexcept
    {
        const auto entered = stageEnteredMs.load(std::memory_order_relaxed);
        const auto now = monotonicMilliseconds();
        return entered == 0 || entered > now ? 0 : now - entered;
    }
    std::uint64_t KDiagramControlRunner::heartbeatAgeMs() const noexcept
    {
        const auto completed = lastCompletedPumpMs.load(std::memory_order_relaxed);
        const auto now = monotonicMilliseconds();
        return completed == 0 || completed > now ? 0 : now - completed;
    }
    const char* KDiagramControlRunner::diagnosticStageName(DiagnosticStage stage) noexcept
    {
        switch (stage) {
        case DiagnosticStage::idle: return "idle";
        case DiagnosticStage::createModel: return "create-model";
        case DiagnosticStage::persistence: return "persistence";
        case DiagnosticStage::exportState: return "export-state";
        case DiagnosticStage::importState: return "import-state";
        case DiagnosticStage::applyCommands: return "apply-commands";
        case DiagnosticStage::advanceTime: return "advance-time";
        case DiagnosticStage::drainEvents: return "drain-events";
        case DiagnosticStage::graphSnapshot: return "graph-snapshot";
        case DiagnosticStage::cursorSnapshot: return "cursor-snapshot";
        case DiagnosticStage::publishVisual: return "publish-visual";
        case DiagnosticStage::destroyModel: return "destroy-model";
        }
        return "unknown";
    }
} // namespace worldofcake::bridge
