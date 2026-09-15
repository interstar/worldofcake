#pragma once

#include "ControlThread.h"
#include "SpscRingBuffer.h"
#include "StatePersistence.h"
#include "WorldOfCakeBridgeTypes.h"

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <string>

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

            bool start(double periodSeconds, double callbackDeltaSeconds = 0.0)
            {
                return controlThread.start(
                    periodSeconds, [this](double tickDelta) { pump(tickDelta); }, [this] { createModel(); },
                    [this] { destroyModel(); }, callbackDeltaSeconds);
            }

            void stop()
            {
                controlThread.stop();
            }
            bool isRunning() const noexcept
            {
                return controlThread.isRunning();
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
            }

            virtual void pump(double delta) = 0;
            virtual void createModel() = 0;
            virtual void destroyModel() = 0;
            virtual void applyCommand(const ControlCommand& command) = 0;

            double logicalTime = 0.0;
            StatePersistence persistence;

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
        };
    } // namespace bridge
} // namespace worldofcake
