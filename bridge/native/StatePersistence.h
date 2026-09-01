#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <string>
#include <utility>

namespace worldofcake
{
    namespace bridge
    {
        /** Bounded Rack persistence request/response mailbox serviced by the control thread. */
        class StatePersistence
        {
          public:
            using Export = std::function<std::string()>;
            using Import = std::function<void(const std::string&)>;

            std::string requestExport(bool running)
            {
                if (!running)
                    return "{}";
                std::unique_lock<std::mutex> lock(mutex);
                if (!ready.wait_for(lock, timeout(), [this] { return request == Request::none; })) {
                    timeoutCount++;
                    return "{}";
                }
                request = Request::exportState;
                complete = false;
                abandoned = false;
                if (!ready.wait_for(lock, timeout(), [this] { return complete; })) {
                    timeoutCount++;
                    abandoned = true;
                    if (!inProgress)
                        request = Request::none;
                    ready.notify_all();
                    return "{}";
                }
                auto result = text;
                request = Request::none;
                complete = false;
                inProgress = false;
                abandoned = false;
                ready.notify_all();
                return result;
            }

            void requestImport(bool running, const std::string& value)
            {
                if (!running)
                    return;
                std::unique_lock<std::mutex> lock(mutex);
                if (!ready.wait_for(lock, timeout(), [this] { return request == Request::none; })) {
                    timeoutCount++;
                    return;
                }
                text = value;
                request = Request::importState;
                complete = false;
                abandoned = false;
                if (!ready.wait_for(lock, timeout(), [this] { return complete; })) {
                    timeoutCount++;
                    abandoned = true;
                    if (!inProgress)
                        request = Request::none;
                    ready.notify_all();
                    return;
                }
                request = Request::none;
                complete = false;
                inProgress = false;
                abandoned = false;
                ready.notify_all();
            }

            std::uint64_t timeouts() const noexcept
            {
                return timeoutCount.load(std::memory_order_relaxed);
            }
            std::uint64_t exportStarts() const noexcept
            {
                return exportStartCount.load(std::memory_order_relaxed);
            }
            std::uint64_t exportCompletions() const noexcept
            {
                return exportCompletionCount.load(std::memory_order_relaxed);
            }

            void service(const Export& exportState, const Import& importState)
            {
                Request work = Request::none;
                std::string input;
                {
                    std::lock_guard<std::mutex> lock(mutex);
                    if (request != Request::none && !complete && !inProgress) {
                        work = request;
                        inProgress = true;
                        if (work == Request::importState)
                            input = text;
                    }
                }
                if (work == Request::exportState) {
                    exportStartCount++;
                    auto result = exportState();
                    exportCompletionCount++;
                    std::lock_guard<std::mutex> lock(mutex);
                    if (request == work && !abandoned) {
                        text = std::move(result);
                        complete = true;
                    } else {
                        request = Request::none;
                        complete = false;
                        abandoned = false;
                    }
                    inProgress = false;
                    ready.notify_all();
                } else if (work == Request::importState) {
                    importState(input);
                    std::lock_guard<std::mutex> lock(mutex);
                    if (request == work && !abandoned)
                        complete = true;
                    else {
                        request = Request::none;
                        complete = false;
                        abandoned = false;
                    }
                    inProgress = false;
                    ready.notify_all();
                }
            }

          private:
            enum class Request
            {
                none,
                exportState,
                importState
            };
            static std::chrono::milliseconds timeout()
            {
                return std::chrono::milliseconds(500);
            }
            std::mutex mutex;
            std::condition_variable ready;
            Request request = Request::none;
            bool complete = false;
            bool inProgress = false;
            bool abandoned = false;
            std::string text;
            std::atomic<std::uint64_t> timeoutCount{0};
            std::atomic<std::uint64_t> exportStartCount{0};
            std::atomic<std::uint64_t> exportCompletionCount{0};
        };
    } // namespace bridge
} // namespace worldofcake
