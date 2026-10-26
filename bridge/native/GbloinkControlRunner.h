#pragma once

#include "HarnessControlRunner.h"
#include "SpscRingBuffer.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/GbloinkHarness.h>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

namespace worldofcake::bridge
{
    /**
        Manual-pump Stage 1 runner. Only its control owner may call pump().
        UI and audio consumers communicate through bounded native queues/snapshots.
    */
    class GbloinkControlRunner : public HarnessControlRunner<worldofcake::bridge::GbloinkHarness_obj>
    {
      public:
        GbloinkControlRunner(double width, double height, int seed);
        ~GbloinkControlRunner();

        GbloinkControlRunner(const GbloinkControlRunner&) = delete;
        GbloinkControlRunner& operator=(const GbloinkControlRunner&) = delete;

        void pump(double delta) override;

        /** Real-time-safe: native bounded queue only; never enters Haxe. */
        bool popPreparedEvent(PreparedEvent& event) noexcept;

        /** UI-side snapshot copy; never enters Haxe. */
        GbloinkVisualSnapshot latestVisualSnapshot() const;

        std::uint64_t droppedEvents() const noexcept
        {
            return eventDrops.load();
        }
        std::uint64_t preparedEventCount() const noexcept
        {
            return preparedEvents.load(std::memory_order_relaxed);
        }
        std::uint64_t controlTicks() const noexcept
        {
            return controlTickCount.load(std::memory_order_relaxed);
        }
        std::uint64_t stateRequestTimeouts() const noexcept
        {
            return persistence.timeouts();
        }
        int controlStage() const noexcept
        {
            return currentStage.load(std::memory_order_relaxed);
        }
        std::uint64_t stateExportStarts() const noexcept
        {
            return persistence.exportStarts();
        }
        std::uint64_t stateExportCompletions() const noexcept
        {
            return persistence.exportCompletions();
        }

      private:
        void applyAppCommand(const ControlCommand& command) override;
        void drainEvents();
        void publishVisualSnapshot();
        void createModel() override;
        void destroyModel() override;

        SpscRingBuffer<PreparedEvent, 256> events;
        std::atomic<std::uint64_t> eventDrops{0};
        std::atomic<std::uint64_t> preparedEvents{0};
        std::atomic<std::uint64_t> controlTickCount{0};
        std::atomic<int> currentStage{0};
        mutable std::mutex snapshotMutex;
        GbloinkVisualSnapshot snapshot;
        std::uint64_t nextGeneration = 1;
        double modelWidth = 0.0;
        double modelHeight = 0.0;
        int modelSeed = 0;
        bool modelCreated = false;
        std::uint64_t observedHostTransportEpoch = 0;
        double hostClockBaseTime = 0.0;
    };
} // namespace worldofcake::bridge
