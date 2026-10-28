#include "TileLandControlRunner.h"
#include "WorldOfCakeControlIds.h"
#include <worldofcake/generated/tileland/TilelandControlMetadataGenerated.h>
#include <algorithm>
#include <cmath>
namespace worldofcake::bridge
{
    namespace ControlIds = worldofcake::control::tileland;
    TileLandControlRunner::TileLandControlRunner(int seed) : modelSeed(seed)
    {
    }
    TileLandControlRunner::~TileLandControlRunner()
    {
        stop();
    }
    void TileLandControlRunner::pump(double d)
    {
        if (!modelCreated)
            createModel();
        persistence.service([this] { return harness->exportStateJson().utf8_str(); },
                            [this](const std::string& s) {
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                cachedTileVersion = -1;
                                publishSnapshots();
                            });
        applyPendingCommands();
        if (std::isfinite(d) && d > 0) {
            harness->advanceTime(d);
            harness->discardPendingEvents();
            logicalTime += d;
        }
        publishSnapshots();
    }
    bool TileLandControlRunner::popControlSnapshot(TileLandControlSnapshot& v) noexcept
    {
        return controlSnapshots.pop(v);
    }
    TileLandVisualSnapshot TileLandControlRunner::latestVisualSnapshot() const
    {
        std::lock_guard<std::mutex> l(visualMutex);
        return visualSnapshot;
    }
    void TileLandControlRunner::applyAppCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.x, c.y);
        else if (c.kind == CommandKind::setValue) {
            for (int i = 0; i < ControlIds::kSpeedCount; ++i)
                if (c.controlId == ControlIds::speedUid(i))
                    harness->setSpeed(i, c.value);
        }
    }
    TileLandControlSnapshot TileLandControlRunner::captureControlSnapshot(std::uint64_t g)
    {
        TileLandControlSnapshot n;
        n.generation = g;
        n.modelReady = harness->modelReady();
        n.stateRevision = static_cast<std::uint64_t>(harness->stateRevision());
        n.logicalTime = logicalTime;
        for (int i = 0; i < 3; i++) {
            n.values[i * 2] = std::max(0, std::min(127, (int)(harness->cursorX(i) / worldofcake::metadata::tileland::model::kWorldWidth * 127)));
            n.values[i * 2 + 1] = std::max(0, std::min(127, 127 - (int)(harness->cursorY(i) / worldofcake::metadata::tileland::model::kWorldHeight * 127)));
        }
        return n;
    }
    TileLandVisualSnapshot TileLandControlRunner::captureVisualSnapshot(std::uint64_t g)
    {
        TileLandVisualSnapshot n;
        n.generation = g;
        n.modelReady = harness->modelReady();
        n.stateRevision = static_cast<std::uint64_t>(harness->stateRevision());
        n.logicalTime = logicalTime;
        n.paused = harness->paused();
        n.rows = harness->rows();
        n.cols = harness->cols();
        auto version = harness->tileVisualVersion();
        if (version != cachedTileVersion) {
            for (int r = 0; r < n.rows; r++)
                for (int c = 0; c < n.cols; c++)
                    n.tileTypes[(size_t)(r * n.cols + c)].orientation =
                        harness->tileType(c, r) == 1 ? TileOrientation::A : TileOrientation::B;
            cachedTileVersion = version;
        } else {
            n.tileTypes = visualSnapshot.tileTypes;
        }
        for (int i = 0; i < 3; i++) {
            auto& q = n.cursors[i];
            q.x = harness->cursorX(i);
            q.y = harness->cursorY(i);
            q.colour = harness->cursorColour(i);
            q.speed = harness->cursorSpeed(i);
        }
        return n;
    }
    void TileLandControlRunner::publishSnapshots()
    {
        auto g = nextGeneration++;
        auto c = captureControlSnapshot(g);
        if (!controlSnapshots.push(c))
            snapshotDrops++;
        auto n = captureVisualSnapshot(g);
        std::lock_guard<std::mutex> l(visualMutex);
        visualSnapshot = std::move(n);
    }
    void TileLandControlRunner::createModel()
    {
        if (modelCreated)
            return;
        harness = TileLandHarness_obj::__new(modelSeed);
        modelCreated = true;
        logicalTime = 0;
        publishSnapshots();
    }
    void TileLandControlRunner::destroyModel()
    {
        if (!modelCreated)
            return;
        harness->destroy();
        harness = nullptr;
        modelCreated = false;
    }
} // namespace worldofcake::bridge
