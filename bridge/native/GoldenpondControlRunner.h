#pragma once
#include "ControlRunnerBase.h"
#include "SpscRingBuffer.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/GoldenpondHarness.h>
#include <atomic>
#include <mutex>

namespace worldofcake::bridge {
class GoldenpondControlRunner : public ControlRunnerBase {
  public:
    GoldenpondControlRunner()
    {
        for (std::size_t note = 0; note < correctionMap.size(); ++note)
            correctionMap[note].store(static_cast<int>(note % 128), std::memory_order_relaxed);
    }
    ~GoldenpondControlRunner() override;
    void pump(double delta) override;
    bool popPreparedEvent(PreparedEvent& event) noexcept;
    void requestVisualSnapshot() noexcept { snapshotRequested.store(true, std::memory_order_release); }
    GoldenpondVisualSnapshot latestVisualSnapshot() const;
    int correctedNote(int note, int column = 0) const noexcept
    {
        if (note < 0 || note >= 128 || column < 0 || column > 2) return note;
        return correctionMap[static_cast<std::size_t>(column * 128 + note)].load(std::memory_order_relaxed);
    }
    std::uint64_t droppedEvents() const noexcept
    {
        return eventDrops.load(std::memory_order_relaxed);
    }
    std::uint64_t producedEvents() const noexcept { return produced.load(std::memory_order_relaxed); }
    std::uint64_t poppedEvents() const noexcept { return popped.load(std::memory_order_relaxed); }
    std::uint64_t correctionTableRefreshes() const noexcept
    {
        return correctionRefreshes.load(std::memory_order_relaxed);
    }
  private:
    void createModel() override;
    void destroyModel() override;
    void applyCommand(const ControlCommand& command) override;
    void drainEvents();
    void publishVisualSnapshot();
    SpscRingBuffer<PreparedEvent, 2048> events;
    std::atomic<std::uint64_t> eventDrops{0};
    std::atomic<std::uint64_t> produced{0};
    std::atomic<std::uint64_t> popped{0};
    ::hx::ObjectPtr<GoldenpondHarness_obj> harness;
    bool modelCreated = false;
    mutable std::mutex snapshotMutex;
    GoldenpondVisualSnapshot snapshot;
    std::uint64_t nextGeneration = 1;
    // Columns: neutral/first pitch, ascending phrase, descending phrase.
    std::array<std::atomic<int>, 384> correctionMap{};
    std::uint64_t observedHostTransportEpoch = 0;
    double hostClockBaseTime = 0.0;
    double hostClockBaseLogicalTime = 0.0;
    std::atomic<std::uint64_t> correctionRefreshes{0};
    int correctionKey = -1;
    std::atomic<bool> snapshotRequested{false};
};
}
