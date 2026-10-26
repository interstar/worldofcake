#include <hxcpp.h>

#include "GoldenpondControlRunner.h"
#include "WorldOfCakeBridgeTypes.h"
#include "generated/goldenpond/GoldenpondControlIdsGenerated.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <thread>
#include <vector>
#include <unistd.h>

extern "C" void __hxcpp_lib_main();
void __boot_all();

extern "C" void __hxcpp_lib_main() {
    HX_TOP_OF_STACK
    ::hx::Boot();
    __boot_all();
}

namespace {
using namespace std::chrono;
using worldofcake::bridge::CommandKind;
using worldofcake::bridge::ControlCommand;
using worldofcake::bridge::GoldenpondControlRunner;
using worldofcake::bridge::PreparedEvent;

constexpr double kControlPeriod = 1.0 / 60.0;
constexpr int kAudioBlockSize = 64;
constexpr int kSampleRate = 48000;
constexpr auto kStallLimit = seconds(15);

int parsePositive(const char* value, int fallback) {
    if (value == nullptr) return fallback;
    const int parsed = std::atoi(value);
    return parsed > 0 ? parsed : fallback;
}

void sendValue(GoldenpondControlRunner& runner, int id, double value, std::uint64_t sequence) {
    ControlCommand command;
    command.kind = CommandKind::setValue;
    command.sequence = sequence;
    command.controlId = id;
    command.value = value;
    runner.enqueueHostCommand(command);
}
}

int main(int argc, char** argv) {
    const int durationSeconds = parsePositive(argc > 1 ? argv[1] : nullptr, 300);
    const int runnerCount = std::min(16, parsePositive(argc > 2 ? argv[2] : nullptr, 4));

    int stackAnchor = 0;
    hx::SetTopOfStack(&stackAnchor, true);
    __hxcpp_lib_main();
    hx::AutoGCFreeZone gcFreeMainThread;

    std::vector<std::unique_ptr<GoldenpondControlRunner>> runners;
    runners.reserve(static_cast<std::size_t>(runnerCount));
    for (int i = 0; i < runnerCount; ++i) {
        auto runner = std::unique_ptr<GoldenpondControlRunner>(new GoldenpondControlRunner());
        if (!runner->start(kControlPeriod)) {
            std::cerr << "FAIL: could not start control runner " << i << '\n';
            return 1;
        }
        sendValue(*runner, generated::goldenpond::GoldenpondControlIdsGenerated_obj::BPM, 240.0, 1);
        sendValue(*runner, generated::goldenpond::GoldenpondControlIdsGenerated_obj::CHORDDURATION, 1.0, 2);
        runners.push_back(std::move(runner));
    }

    std::atomic<bool> stopAudio{false};
    std::atomic<std::uint64_t> audioBlocks{0};
    std::atomic<std::uint64_t> audioChecksum{0};
    std::thread audioThread([&] {
        const auto blockPeriod = duration<double>(static_cast<double>(kAudioBlockSize) / kSampleRate);
        double hostTransportTime = 0.0;
        auto deadline = steady_clock::now();
        while (!stopAudio.load(std::memory_order_acquire)) {
            hostTransportTime += blockPeriod.count();
            for (const auto& runner : runners)
                runner->setHostTransportTime(hostTransportTime, 0);
            std::uint64_t checksum = 0;
            for (int sample = 0; sample < kAudioBlockSize; ++sample) {
                for (const auto& runner : runners) {
                    checksum += static_cast<std::uint64_t>(runner->correctedNote(48));
                    checksum += static_cast<std::uint64_t>(runner->correctedNote(61));
                    checksum += static_cast<std::uint64_t>(runner->correctedNote(73));
                }
            }
            for (const auto& runner : runners) {
                PreparedEvent event;
                while (runner->popPreparedEvent(event)) checksum += static_cast<std::uint64_t>(event.type + 1);
            }
            audioChecksum.fetch_add(checksum, std::memory_order_relaxed);
            audioBlocks.fetch_add(1, std::memory_order_relaxed);
            deadline += duration_cast<steady_clock::duration>(blockPeriod);
            std::this_thread::sleep_until(deadline);
            if (deadline < steady_clock::now() - duration_cast<steady_clock::duration>(blockPeriod))
                deadline = steady_clock::now();
        }
    });

    std::vector<std::uint64_t> lastGeneration(static_cast<std::size_t>(runnerCount), 0);
    std::vector<steady_clock::time_point> lastAdvance(static_cast<std::size_t>(runnerCount), steady_clock::now());
    const auto started = steady_clock::now();
    auto nextReport = started + seconds(10);
    auto nextParameterChange = started + seconds(5);
    auto nextPersistenceRequest = started + seconds(15);
    std::uint64_t persistenceBytes = 0;
    std::uint64_t persistenceRequests = 0;
    while (steady_clock::now() - started < seconds(durationSeconds)) {
        const auto now = steady_clock::now();
        for (int i = 0; i < runnerCount; ++i) {
            const auto snapshot = runners[static_cast<std::size_t>(i)]->latestVisualSnapshot();
            auto& seen = lastGeneration[static_cast<std::size_t>(i)];
            if (snapshot.generation > seen) {
                seen = snapshot.generation;
                lastAdvance[static_cast<std::size_t>(i)] = now;
            } else if (now - lastAdvance[static_cast<std::size_t>(i)] > kStallLimit) {
                std::cerr << "FAIL: runner " << i << " visual snapshot stopped advancing at generation "
                          << seen << "; pid=" << getpid() << std::endl;
                if (const char* hold = std::getenv("WOC_STRESS_HOLD_ON_STALL")) {
                    if (hold[0] == '1') {
                        std::cerr << "Holding process for debugger attachment; interrupt it after collecting stacks."
                                  << std::endl;
                        for (;;) std::this_thread::sleep_for(hours(1));
                    }
                }
                std::_Exit(2);
            }

        }

        if (now >= nextParameterChange) {
            for (int i = 0; i < runnerCount; ++i) {
                sendValue(*runners[static_cast<std::size_t>(i)],
                          generated::goldenpond::GoldenpondControlIdsGenerated_obj::BPM,
                          (i % 2 == 0) ? 240.0 : 180.0,
                          static_cast<std::uint64_t>(duration_cast<seconds>(now - started).count()));
            }
            nextParameterChange += seconds(5);
        }

        if (now >= nextPersistenceRequest) {
            for (auto& runner : runners) {
                const auto state = runner->exportStateJson();
                persistenceBytes += state.size();
                ++persistenceRequests;
            }
            nextPersistenceRequest += seconds(15);
        }

        if (now >= nextReport) {
            const auto elapsed = duration_cast<seconds>(now - started).count();
            std::uint64_t generations = 0;
            for (const auto generation : lastGeneration) generations += generation;
            std::cout << "alive: " << elapsed << "s, runners=" << runnerCount
                      << ", snapshots=" << generations
                      << ", audioBlocks=" << audioBlocks.load(std::memory_order_relaxed)
                      << ", stateExports=" << persistenceRequests << '\n';
            nextReport += seconds(10);
        }
        std::this_thread::sleep_for(milliseconds(100));
    }

    stopAudio.store(true, std::memory_order_release);
    audioThread.join();
    for (auto& runner : runners) runner->stop();

    std::uint64_t totalGeneration = 0;
    std::uint64_t totalTableRefreshes = 0;
    for (const auto generation : lastGeneration) totalGeneration += generation;
    for (int i = 0; i < runnerCount; ++i) {
        const auto refreshes = runners[static_cast<std::size_t>(i)]->correctionTableRefreshes();
        totalTableRefreshes += refreshes;
        if (refreshes < 2) {
            std::cerr << "FAIL: runner " << i << " published only " << refreshes
                      << " correction table(s)\n";
            return 3;
        }
    }
    std::cout << "PASS: " << durationSeconds << "s, " << runnerCount << " concurrent Rack runners"
              << ", snapshots=" << totalGeneration
              << ", audioBlocks=" << audioBlocks.load(std::memory_order_relaxed)
              << ", stateExports=" << persistenceRequests
              << ", stateBytes=" << persistenceBytes
              << ", correctionTableRefreshes=" << totalTableRefreshes
              << ", audioChecksum=" << audioChecksum.load(std::memory_order_relaxed) << '\n';
    return 0;
}
