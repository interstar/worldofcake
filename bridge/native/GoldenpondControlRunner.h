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
        for (int note = 0; note < 128; ++note)
            correctionMap[static_cast<std::size_t>(note)].store(note, std::memory_order_relaxed);
    }
    ~GoldenpondControlRunner() override;
    void pump(double delta) override;
    bool popPreparedEvent(PreparedEvent& event) noexcept;
    GoldenpondVisualSnapshot latestVisualSnapshot() const;
    int correctedNote(int note) const noexcept
    {
        return correctionMap[static_cast<std::size_t>(note)].load(std::memory_order_relaxed);
    }
    std::uint64_t droppedEvents() const noexcept
    {
        return eventDrops.load(std::memory_order_relaxed);
    }
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
    SpscRingBuffer<PreparedEvent, 512> events;
    std::atomic<std::uint64_t> eventDrops{0};
    ::hx::ObjectPtr<GoldenpondHarness_obj> harness;
    bool modelCreated = false;
    mutable std::mutex snapshotMutex;
    GoldenpondVisualSnapshot snapshot;
    std::uint64_t nextGeneration = 1;
    std::array<std::atomic<int>, 128> correctionMap{};
    std::atomic<std::uint64_t> correctionRefreshes{0};
    int correctionRevision = -1;
    int correctionChordIndex = -2;
};
}
