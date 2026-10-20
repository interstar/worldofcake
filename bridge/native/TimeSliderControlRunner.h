#pragma once

#include "ControlRunnerBase.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/TimeSliderHarness.h>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

namespace worldofcake::bridge
{
    /** TimeSlider adapter using the same lifecycle and command transport as Gbloink. */
    class TimeSliderControlRunner : public ControlRunnerBase
    {
      public:
        TimeSliderControlRunner(int width, int height, double slowSeconds, double fastSeconds);
        ~TimeSliderControlRunner();

        TimeSliderControlRunner(const TimeSliderControlRunner&) = delete;
        TimeSliderControlRunner& operator=(const TimeSliderControlRunner&) = delete;

        void pump(double delta) override;
        /** Real-time-safe continuous-state channel; does not enter Haxe or lock. */
        bool popControlSnapshot(TimeSliderControlSnapshot& value) noexcept;
        bool popPreparedEvent(PreparedEvent& value) noexcept;
        TimeSliderControlSnapshot latestVisualSnapshot() const;

        std::uint64_t droppedSnapshots() const noexcept
        {
            return snapshotDrops.load();
        }

      private:
        void createModel() override;
        void destroyModel() override;
        void applyCommand(const ControlCommand& command) override;
        TimeSliderControlSnapshot captureSnapshot();
        void publishSnapshot();
        void drainEvents();

        SpscRingBuffer<TimeSliderControlSnapshot, 64> controlSnapshots;
        SpscRingBuffer<PreparedEvent, 512> events;
        std::atomic<std::uint64_t> snapshotDrops{0};
        std::atomic<std::uint64_t> eventDrops{0};
        mutable std::mutex visualMutex;
        TimeSliderControlSnapshot visualSnapshot;
        std::uint64_t nextGeneration = 1;
        ::hx::ObjectPtr<TimeSliderHarness_obj> harness;
        int modelWidth = 0, modelHeight = 0;
        double modelSlow = 0.0, modelFast = 0.0;
        bool modelCreated = false;
    };
} // namespace worldofcake::bridge
