#pragma once
#include "HarnessControlRunner.h"
#include "SpscRingBuffer.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/ZewpHarness.h>
#include <atomic>
#include <cstdint>
#include <mutex>
namespace worldofcake::bridge
{
    class ZewpControlRunner : public HarnessControlRunner<ZewpHarness_obj>
    {
      public:
        /** The model's world size is fixed by the app (metadata::zewp::model). */
        explicit ZewpControlRunner(int seed);
        ~ZewpControlRunner();
        ZewpControlRunner(const ZewpControlRunner&) = delete;
        ZewpControlRunner& operator=(const ZewpControlRunner&) = delete;
        bool popControlSnapshot(ZewpControlSnapshot&) noexcept;
        ZewpVisualSnapshot latestVisualSnapshot() const;
        std::uint64_t droppedSnapshots() const noexcept
        {
            return snapshotDrops.load();
        }

      private:
        void createModel() override;
        void destroyModel() override;
        void pump(double) override;
        void applyAppCommand(const ControlCommand&) override;
        void publish();
        double width, height;
        int seed;
        std::uint64_t generation = 1;
        bool modelCreated = false;
        SpscRingBuffer<ZewpControlSnapshot, 64> controls;
        std::atomic<std::uint64_t> snapshotDrops{0};
        mutable std::mutex visualMutex;
        ZewpVisualSnapshot visual;
    };
} // namespace worldofcake::bridge
