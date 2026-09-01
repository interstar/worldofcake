#include "ZewpControlRunner.h"
#include <algorithm>
#include <cmath>
namespace worldofcake::bridge
{
    ZewpControlRunner::ZewpControlRunner(int w, int h, int s) : width(w), height(h), seed(s)
    {
    }
    ZewpControlRunner::~ZewpControlRunner()
    {
        stop();
        destroyModel();
    }
    void ZewpControlRunner::createModel()
    {
        if (modelCreated)
            return;
        harness = ZewpHarness_obj::__new(width, height, seed);
        modelCreated = true;
        logicalTime = 0;
        publish();
    }
    void ZewpControlRunner::destroyModel()
    {
        if (!modelCreated)
            return;
        harness->destroy();
        harness = nullptr;
        modelCreated = false;
    }
    void ZewpControlRunner::pump(double d)
    {
        if (!modelCreated)
            createModel();
        persistence.service([this] { return harness->exportStateJson().utf8_str(); },
                            [this](const std::string& s) {
                                harness->importStateJson(::String(s.c_str()));
                                logicalTime = harness->logicalTime();
                                publish();
                            });
        applyPendingCommands();
        if (std::isfinite(d) && d > 0) {
            harness->advanceTime(d);
            harness->discardPendingEvents();
            logicalTime += d;
        }
        publish();
    }
    void ZewpControlRunner::applyCommand(const ControlCommand& c)
    {
        if (c.kind == CommandKind::playAreaClick)
            harness->click(c.x, c.y);
        else if (c.kind == CommandKind::playAreaDrag)
            harness->dragTo(c.x, c.y);
        else if (c.kind == CommandKind::playAreaRelease)
            harness->release(c.x, c.y);
        else if (c.kind == CommandKind::setValue) {
            if (c.controlId == 10)
                harness->setPopulation(c.value);
            else if (c.controlId == 11)
                harness->setSpeed(c.value);
            else if (c.controlId == 20)
                harness->reset();
            else if (c.controlId == 21)
                harness->setPaused(c.value > .5);
        }
    }
    void ZewpControlRunner::publish()
    {
        const auto g = generation++;
        ZewpControlSnapshot c{};
        c.generation = g;
        c.logicalTime = logicalTime;
        for (int i = 0; i < 6; ++i) {
            if (i < harness->count()) {
                c.values[i * 3] = std::max(0, std::min(127, (int)(harness->x(i) / width * 127)));
                c.values[i * 3 + 1] = std::max(0, std::min(127, (int)(harness->y(i) / height * 127)));
                c.values[i * 3 + 2] = harness->inFront(i) ? 1 : 0;
            }
        }
        if (!controls.push(c))
            snapshotDrops++;
        ZewpVisualSnapshot v;
        v.generation = g;
        v.logicalTime = logicalTime;
        v.paused = harness->paused();
        v.population = harness->population();
        v.speedMultiplier = harness->speedMultiplier();
        for (int i = 0, n = harness->count(); i < n; ++i) {
            ZewpAgentSnapshot a;
            a.x = harness->x(i);
            a.y = harness->y(i);
            a.angle = harness->angle(i);
            a.length = harness->length(i);
            a.colour = harness->colour(i);
            v.agents.push_back(a);
        }
        for (int i = 0, n = harness->blockCount(); i < n; ++i) {
            ZewpBlockSnapshot b;
            b.x = harness->blockX(i);
            b.y = harness->blockY(i);
            b.width = harness->blockWidth(i);
            b.height = harness->blockHeight(i);
            b.colour = 0xffffff;
            v.blocks.push_back(b);
        }
        const std::lock_guard<std::mutex> l(visualMutex);
        visual = std::move(v);
    }
    bool ZewpControlRunner::popControlSnapshot(ZewpControlSnapshot& s) noexcept
    {
        return controls.pop(s);
    }
    ZewpVisualSnapshot ZewpControlRunner::latestVisualSnapshot() const
    {
        const std::lock_guard<std::mutex> l(visualMutex);
        return visual;
    }
} // namespace worldofcake::bridge
