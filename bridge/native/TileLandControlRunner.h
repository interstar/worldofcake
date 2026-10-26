#pragma once

#include "HarnessControlRunner.h"
#include "SpscRingBuffer.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/TileLandHarness.h>

#include <atomic>
#include <cstdint>
#include <mutex>

namespace worldofcake::bridge
{
    /** TileLand adapter using the common dual-input lifecycle and publication boundary. */
    class TileLandControlRunner : public HarnessControlRunner<TileLandHarness_obj>
    {
      public:
        explicit TileLandControlRunner(int seed);
        ~TileLandControlRunner();

        TileLandControlRunner(const TileLandControlRunner&) = delete;
        TileLandControlRunner& operator=(const TileLandControlRunner&) = delete;

        void pump(double delta) override;

        /** Real-time-safe six-value output channel; native queue only. */
        bool popControlSnapshot(TileLandControlSnapshot& value) noexcept;
        TileLandVisualSnapshot latestVisualSnapshot() const;

        std::uint64_t droppedSnapshots() const noexcept
        {
            return snapshotDrops.load();
        }

      private:
        void createModel() override;
        void destroyModel() override;
        void applyAppCommand(const ControlCommand& command) override;
        TileLandControlSnapshot captureControlSnapshot(std::uint64_t generation);
        TileLandVisualSnapshot captureVisualSnapshot(std::uint64_t generation);
        void publishSnapshots();
        SpscRingBuffer<TileLandControlSnapshot, 64> controlSnapshots;
        std::atomic<std::uint64_t> snapshotDrops{0};
        mutable std::mutex visualMutex;
        TileLandVisualSnapshot visualSnapshot;
        int cachedTileVersion = -1;
        std::uint64_t nextGeneration = 1;
        int modelSeed = 0;
        bool modelCreated = false;
    };
} // namespace worldofcake::bridge
