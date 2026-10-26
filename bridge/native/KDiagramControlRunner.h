#pragma once
#include "HarnessControlRunner.h"
#include "SpscRingBuffer.h"
#include "WorldOfCakeBridgeTypes.h"
#include <worldofcake/bridge/KDiagramHarness.h>
#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

namespace worldofcake::bridge
{
    class KDiagramControlRunner : public HarnessControlRunner<KDiagramHarness_obj>
    {
      public:
        enum class DiagnosticStage : int
        {
            idle = 0,
            createModel,
            persistence,
            exportState,
            importState,
            applyCommands,
            advanceTime,
            drainEvents,
            graphSnapshot,
            cursorSnapshot,
            publishVisual,
            destroyModel
        };

        explicit KDiagramControlRunner(int seed);
        ~KDiagramControlRunner();
        void pump(double delta) override;
        bool popPreparedEvent(PreparedEvent&) noexcept;
        KDiagramVisualSnapshot latestVisualSnapshot() const;
        std::uint64_t droppedEvents() const noexcept
        {
            return eventDrops.load();
        }
        std::uint64_t droppedSnapshots() const noexcept
        {
            return snapshotDrops.load();
        }
        std::uint64_t controlPumpStarts() const noexcept
        {
            return pumpStartCount.load(std::memory_order_relaxed);
        }
        std::uint64_t controlPumpCompletions() const noexcept
        {
            return pumpCompletionCount.load(std::memory_order_relaxed);
        }
        std::uint64_t stateRequestTimeouts() const noexcept
        {
            return persistence.timeouts();
        }
        std::uint64_t stateExportStarts() const noexcept
        {
            return persistence.exportStarts();
        }
        std::uint64_t stateExportCompletions() const noexcept
        {
            return persistence.exportCompletions();
        }
        DiagnosticStage diagnosticStage() const noexcept
        {
            return static_cast<DiagnosticStage>(currentStage.load(std::memory_order_relaxed));
        }
        std::uint64_t diagnosticStageAgeMs() const noexcept;
        std::uint64_t heartbeatAgeMs() const noexcept;
        static const char* diagnosticStageName(DiagnosticStage) noexcept;

      private:
        void createModel() override;
        void destroyModel() override;
        void applyAppCommand(const ControlCommand&) override;
        void drainEvents();
        void publishSnapshots();
        void setDiagnosticStage(DiagnosticStage) noexcept;
        static std::uint64_t monotonicMilliseconds() noexcept;
        SpscRingBuffer<PreparedEvent, 256> events;
        std::atomic<std::uint64_t> eventDrops{0}, snapshotDrops{0};
        std::atomic<std::uint64_t> pumpStartCount{0}, pumpCompletionCount{0};
        std::atomic<std::uint64_t> lastCompletedPumpMs{0}, stageEnteredMs{0};
        std::atomic<int> currentStage{static_cast<int>(DiagnosticStage::idle)};
        mutable std::mutex visualMutex;
        KDiagramVisualSnapshot visual;
        std::uint64_t nextGeneration = 1;
        int modelSeed = 0;
        bool modelCreated = false;
    };
} // namespace worldofcake::bridge
