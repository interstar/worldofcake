#pragma once

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <thread>

namespace worldofcake::bridge
{
    /** Shared non-real-time control thread used by every native WorldOfCake runner. */
    class ControlThread
    {
      public:
        using Tick = std::function<void(double)>;
        using Lifecycle = std::function<void()>;

        ControlThread() = default;
        ~ControlThread();

        ControlThread(const ControlThread&) = delete;
        ControlThread& operator=(const ControlThread&) = delete;

        bool start(double periodSeconds, Tick tick, Lifecycle setup = {}, Lifecycle teardown = {},
                   double callbackDeltaSeconds = 0.0);
        void stop();
        bool isRunning() const noexcept
        {
            return running.load(std::memory_order_acquire);
        }

      private:
        std::atomic<bool> stopRequested{false};
        std::atomic<bool> running{false};
        std::thread worker;
        std::mutex waitMutex;
        std::condition_variable wake;
        std::mutex startMutex;
        std::condition_variable started;
    };
} // namespace worldofcake::bridge
