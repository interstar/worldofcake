#pragma once

#include "ControlThread.h"
#include "SpscRingBuffer.h"
#include "StatePersistence.h"
#include "WorldOfCakeBridgeTypes.h"

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <string>
#include <cmath>

namespace worldofcake
{
    namespace bridge
    {
        /** Common native runner shell for dual-producer host/gui command queues and persistence requests. */
        class ControlRunnerBase
        {
          public:
            virtual ~ControlRunnerBase()
            {
            }

            ControlRunnerBase(const ControlRunnerBase&) = delete;
            ControlRunnerBase& operator=(const ControlRunnerBase&) = delete;

            bool enqueueGuiCommand(const ControlCommand& command) noexcept
            {
                if (guiCommands.push(command)) {
                    updateHighWater(guiCommandHighWater, guiCommands.sizeApprox());
                    return true;
                }
                guiCommandDrops++;
                return false;
            }

            bool enqueueHostCommand(const ControlCommand& command) noexcept
            {
                if (hostCommands.push(command)) {
                    updateHighWater(hostCommandHighWater, hostCommands.sizeApprox());
                    return true;
                }
                hostCommandDrops++;
                return false;
            }

            bool start(double periodSeconds)
            {
                return controlThread.start(
                    periodSeconds,
                    [this](double tickDelta) {
                        pump(tickDelta);
                        onTickComplete();
                    },
                    [this] { createModel(); },
                    [this] { destroyModel(); });
            }

            void stop()
            {
                controlThread.stop();
            }
            bool isRunning() const noexcept
            {
                return controlThread.isRunning();
            }

            /** Real-time-safe latest-value host clock publication. */
            void setHostTransportTime(double elapsedSeconds, std::uint64_t epoch) noexcept
            {
                if (!std::isfinite(elapsedSeconds) || elapsedSeconds < 0.0)
                    return;
                hostTransportTime.store(elapsedSeconds, std::memory_order_release);
                hostTransportEpoch.store(epoch, std::memory_order_release);
                hostClockEnabled.store(true, std::memory_order_release);
            }

            void setHostTransportRunning(bool running) noexcept
            {
                hostTransportRunning.store(running, std::memory_order_release);
            }

            void setHostTransportBpm(double bpm) noexcept
            {
                if (std::isfinite(bpm) && bpm > 0.0)
                    hostTransportBpm.store(bpm, std::memory_order_release);
            }

            std::string exportStateJson()
            {
                return persistence.requestExport(isRunning());
            }
            void importStateJson(const std::string& state)
            {
                persistence.requestImport(isRunning(), state);
            }

            std::uint64_t droppedGuiCommands() const noexcept
            {
                return guiCommandDrops.load();
            }
            std::uint64_t droppedHostCommands() const noexcept
            {
                return hostCommandDrops.load();
            }
            std::uint64_t droppedCommands() const noexcept
            {
                return droppedGuiCommands() + droppedHostCommands();
            }
            std::size_t peakGuiCommandDepth() const noexcept
            {
                return guiCommandHighWater.load();
            }
            std::size_t peakHostCommandDepth() const noexcept
            {
                return hostCommandHighWater.load();
            }

            /** Real-time-safe copies of the model's pause/mute flags, refreshed every control tick. */
            bool isModelPaused() const noexcept
            {
                return modelPaused.load(std::memory_order_acquire);
            }
            bool isModelMuted() const noexcept
            {
                return modelMuted.load(std::memory_order_acquire);
            }

            /** Most control outputs a runner publishes (see `ControlOutput` in Haxe). */
            static constexpr int kMaxControlOutputs = 16;

            /** Real-time-safe copies of the model's published control outputs, refreshed every control tick. */
            int controlOutputCount() const noexcept
            {
                return controlOutputCountValue.load(std::memory_order_acquire);
            }
            /** Value 0..1 of a control output; 0 when there is no such output. */
            float controlOutputValue(int index) const noexcept
            {
                if (index < 0 || index >= controlOutputCount())
                    return 0.0f;
                return controlOutputValues[static_cast<std::size_t>(index)].load(std::memory_order_acquire);
            }

          protected:
            ControlRunnerBase()
            {
            }

            void applyPendingCommands()
            {
                ControlCommand command;
                while (hostCommands.pop(command))
                    applyCommand(command);
                while (guiCommands.pop(command))
                    applyCommand(command);
                onCommandsApplied();
            }

            /** Called on the control thread after each command drain. */
            virtual void onCommandsApplied()
            {
            }

            void publishModelLifecycle(bool paused, bool muted) noexcept
            {
                modelPaused.store(paused, std::memory_order_release);
                modelMuted.store(muted, std::memory_order_release);
            }

            /** Called on the control thread after every tick's `pump`. */
            virtual void onTickComplete()
            {
            }

            void publishControlOutput(int index, float value) noexcept
            {
                if (index >= 0 && index < kMaxControlOutputs)
                    controlOutputValues[static_cast<std::size_t>(index)].store(value, std::memory_order_release);
            }
            void publishControlOutputCount(int count) noexcept
            {
                controlOutputCountValue.store(count < 0 ? 0 : (count > kMaxControlOutputs ? kMaxControlOutputs : count),
                                              std::memory_order_release);
            }

            virtual void pump(double delta) = 0;
            virtual void createModel() = 0;
            virtual void destroyModel() = 0;
            virtual void applyCommand(const ControlCommand& command) = 0;

            double logicalTime = 0.0;
            StatePersistence persistence;
            std::atomic<double> hostTransportTime{0.0};
            std::atomic<std::uint64_t> hostTransportEpoch{0};
            std::atomic<bool> hostClockEnabled{false};
            std::atomic<bool> hostTransportRunning{true};
            std::atomic<double> hostTransportBpm{0.0};

          private:
            static void updateHighWater(std::atomic<std::size_t>& highWater, std::size_t depth) noexcept
            {
                auto current = highWater.load();
                while (current < depth && !highWater.compare_exchange_weak(current, depth)) {
                }
            }

            SpscRingBuffer<ControlCommand, 64> guiCommands;
            SpscRingBuffer<ControlCommand, 64> hostCommands;
            ControlThread controlThread;
            std::atomic<std::uint64_t> guiCommandDrops{0};
            std::atomic<std::uint64_t> hostCommandDrops{0};
            std::atomic<std::size_t> guiCommandHighWater{0};
            std::atomic<std::size_t> hostCommandHighWater{0};
            std::atomic<bool> modelPaused{false};
            std::atomic<bool> modelMuted{false};
            std::array<std::atomic<float>, kMaxControlOutputs> controlOutputValues{};
            std::atomic<int> controlOutputCountValue{0};
        };
    } // namespace bridge
} // namespace worldofcake
