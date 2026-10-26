#include "ControlThread.h"

#include <hxcpp.h>
#include <hx/Native.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <utility>

namespace worldofcake::bridge
{
    ControlThread::~ControlThread()
    {
        stop();
    }

    bool ControlThread::start(double periodSeconds, Tick tick, Lifecycle setup, Lifecycle teardown)
    {
        if (worker.joinable() || !std::isfinite(periodSeconds) || periodSeconds <= 0.0 || !tick)
            return false;

        stopRequested.store(false, std::memory_order_release);
        worker = std::thread([this, periodSeconds, callback = std::move(tick),
                              onSetup = std::move(setup), onTeardown = std::move(teardown)] {
            // The control worker is the sole Haxe owner. NativeAttach balances
            // its hxcpp GC registration when the thread exits.
            hx::NativeAttach haxeThread;
            if (onSetup)
                onSetup();
            {
                const std::lock_guard<std::mutex> lock(startMutex);
                running.store(true, std::memory_order_release);
            }
            started.notify_all();

            using Clock = std::chrono::steady_clock;
            const auto period =
                std::chrono::duration_cast<Clock::duration>(std::chrono::duration<double>(periodSeconds));
            auto deadline = Clock::now();
            auto lastTick = deadline;
            while (!stopRequested.load(std::memory_order_acquire)) {
                const auto tickStart = Clock::now();
                const double elapsed = std::chrono::duration<double>(tickStart - lastTick).count();
                lastTick = tickStart;
                const double maxTick = kMaxTickSeconds; // by value: Rack builds as C++11
                const double step = elapsed > 0.0 ? std::min(elapsed, maxTick) : periodSeconds;
                callback(step);
                deadline += period;
                std::unique_lock<std::mutex> lock(waitMutex);
                wake.wait_until(lock, deadline, [this] { return stopRequested.load(std::memory_order_acquire); });
                const auto now = Clock::now();
                if (deadline < now - period)
                    deadline = now;
            }
            if (onTeardown)
                onTeardown();
            running.store(false, std::memory_order_release);
        });

        std::unique_lock<std::mutex> lock(startMutex);
        started.wait(lock, [this] { return running.load(std::memory_order_acquire); });
        return true;
    }

    void ControlThread::stop()
    {
        if (!worker.joinable())
            return;
        stopRequested.store(true, std::memory_order_release);
        wake.notify_all();
        worker.join();
    }
} // namespace worldofcake::bridge
