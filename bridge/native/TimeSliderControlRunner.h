#pragma once

#include "HarnessControlRunner.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/TimeSliderHarness.h>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

namespace worldofcake::bridge
{
    /** TimeSlider adapter using the same lifecycle and command transport as Gbloink. */
    class TimeSliderControlRunner : public HarnessControlRunner<TimeSliderHarness_obj>
    {
      public:
        TimeSliderControlRunner();
        ~TimeSliderControlRunner();

        TimeSliderControlRunner(const TimeSliderControlRunner&) = delete;
        TimeSliderControlRunner& operator=(const TimeSliderControlRunner&) = delete;

        void pump(double delta) override;
        bool popPreparedEvent(PreparedEvent& value) noexcept;
        /** Latest lane values etc., for editors and widgets (copies under a lock; not for the audio thread). */
        TimeSliderControlSnapshot latestVisualSnapshot() const;

      private:
        void createModel() override;
        void destroyModel() override;
        void applyAppCommand(const ControlCommand& command) override;
        TimeSliderControlSnapshot captureSnapshot();
        void publishSnapshot();
        void drainEvents();

        SpscRingBuffer<PreparedEvent, 512> events;
        std::atomic<std::uint64_t> eventDrops{0};
        mutable std::mutex visualMutex;
        TimeSliderControlSnapshot visualSnapshot;
        std::uint64_t nextGeneration = 1;
        bool modelCreated = false;
    };
} // namespace worldofcake::bridge
