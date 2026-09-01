#pragma once
#include "ControlRunnerBase.h"
#include "SpscRingBuffer.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/KDiagramHarness.h>
#include <atomic>
#include <mutex>
#include <string>

namespace worldofcake::bridge
{
    class KDiagramControlRunner : public ControlRunnerBase
    {
      public:
        explicit KDiagramControlRunner(int seed);
        ~KDiagramControlRunner();
        void pump(double delta) override;
        bool popPreparedEvent(PreparedEvent&) noexcept;
        bool popControlSnapshot(KDiagramControlSnapshot&) noexcept;
        KDiagramVisualSnapshot latestVisualSnapshot() const;
        std::uint64_t droppedEvents() const noexcept
        {
            return eventDrops.load();
        }
        std::uint64_t droppedSnapshots() const noexcept
        {
            return snapshotDrops.load();
        }

      private:
        void createModel() override;
        void destroyModel() override;
        void applyCommand(const ControlCommand&) override;
        void drainEvents();
        void publishSnapshots();
        SpscRingBuffer<PreparedEvent, 256> events;
        SpscRingBuffer<KDiagramControlSnapshot, 64> controls;
        std::atomic<std::uint64_t> eventDrops{0}, snapshotDrops{0};
        mutable std::mutex visualMutex;
        KDiagramVisualSnapshot visual;
        std::uint64_t nextGeneration = 1;
        ::hx::ObjectPtr<KDiagramHarness_obj> harness;
        int modelSeed = 0;
        bool modelCreated = false;
    };
} // namespace worldofcake::bridge
