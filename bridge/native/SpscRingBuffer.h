#pragma once

#include <array>
#include <atomic>
#include <cstddef>

namespace worldofcake::bridge
{
    /** Fixed-capacity single-producer/single-consumer queue; one slot is reserved. */
    template <typename Value, std::size_t Capacity> class SpscRingBuffer
    {
        static_assert(Capacity >= 2, "SPSC capacity must be at least two");

      public:
        bool push(const Value& value) noexcept
        {
            const auto write = writeIndex.load(std::memory_order_relaxed);
            const auto next = increment(write);
            if (next == readIndex.load(std::memory_order_acquire))
                return false;
            values[write] = value;
            writeIndex.store(next, std::memory_order_release);
            return true;
        }

        bool pop(Value& value) noexcept
        {
            const auto read = readIndex.load(std::memory_order_relaxed);
            if (read == writeIndex.load(std::memory_order_acquire))
                return false;
            value = values[read];
            readIndex.store(increment(read), std::memory_order_release);
            return true;
        }

        /** Concurrent diagnostic only; the value may change immediately after return. */
        std::size_t sizeApprox() const noexcept
        {
            const auto write = writeIndex.load(std::memory_order_acquire);
            const auto read = readIndex.load(std::memory_order_acquire);
            return write >= read ? write - read : Capacity - read + write;
        }

        static constexpr std::size_t usableCapacity() noexcept
        {
            return Capacity - 1;
        }

      private:
        static constexpr std::size_t increment(std::size_t value) noexcept
        {
            return (value + 1) % Capacity;
        }

        std::array<Value, Capacity> values{};
        std::atomic<std::size_t> readIndex{0};
        std::atomic<std::size_t> writeIndex{0};
    };
} // namespace worldofcake::bridge
