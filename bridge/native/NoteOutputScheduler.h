#pragma once

#include "WorldOfCakeBridgeTypes.h"

#include <array>
#include <cstddef>
#include <cstdint>

namespace worldofcake
{
    namespace bridge
    {
        /**
            Shared audio-thread note output for every host adapter (Rack, JUCE, ...).

            Note lifetimes are decided by the Haxe model: every note-on it emits is
            followed by a note-off, and pause/mute/reset release sounding notes.
            This object only delivers those events on the host's clock:

            - events come out in timestamp order once due; late events immediately;
            - a note-off is never dropped: when full, a pending note-on is discarded
              to make room;
            - it tracks the notes it has emitted, so adapters can derive gates and
              release notes after a host discontinuity the model cannot see
              (bypass, prepareToPlay, a transport jump, module removal).

            Fixed capacity, no allocation. Times are in the adapter's own clock.
        */
        class NoteOutputScheduler
        {
          public:
            // Event kinds, as Haxe's `EventType`. Control changes pass through untracked.
            static constexpr int kNoteOn = 0;
            static constexpr int kControlChange = 1;
            static constexpr int kNoteOff = 2;
            static constexpr int kChannels = 17; // apps use 0-based parts or 1-based MIDI channels
            static constexpr int kNotes = 128;
            static constexpr std::size_t kCapacity = 512;

            /** Queue an event due at `time`. Equal times keep their arrival order. */
            void schedule(double time, const PreparedEvent& event) noexcept
            {
                if (count == kCapacity && !makeRoomFor(event))
                    return;
                std::size_t i = count;
                while (i > 0 && pending[i - 1].time > time) {
                    pending[i] = pending[i - 1];
                    --i;
                }
                pending[i].time = time; // field-wise: Rack builds as C++11
                pending[i].event = event;
                ++count;
            }

            /** Emit every event due at or before `until`, in order: `emit(time, event)`. */
            template <typename Emit>
            void emitDue(double until, Emit&& emit) noexcept
            {
                std::size_t due = 0;
                while (due < count && pending[due].time <= until) {
                    deliver(pending[due].time, pending[due].event, emit);
                    ++due;
                }
                if (due == 0)
                    return;
                for (std::size_t i = due; i < count; ++i)
                    pending[i - due] = pending[i];
                count -= due;
            }

            /**
                Host discontinuity: emit a note-off for every sounding note and drop
                everything pending. Not used for pause/mute/reset, which the model
                handles with its own note-offs.
            */
            template <typename Emit>
            void releaseAll(double time, Emit&& emit) noexcept
            {
                count = 0;
                for (int channel = 0; channel < kChannels; ++channel) {
                    if (perChannel[static_cast<std::size_t>(channel)] == 0)
                        continue;
                    for (int note = 0; note < kNotes; ++note) {
                        auto& n = sounding[index(channel, note)];
                        if (n == 0)
                            continue;
                        PreparedEvent off;
                        off.type = kNoteOff;
                        off.channel = channel;
                        off.data2 = note;
                        for (; n > 0; --n)
                            emit(time, off);
                    }
                    perChannel[static_cast<std::size_t>(channel)] = 0;
                }
            }

            /** Forget everything without output (nothing was ever audible). */
            void clear() noexcept
            {
                count = 0;
                sounding.fill(0);
                perChannel.fill(0);
            }

            int soundingNotes(int channel) const noexcept
            {
                return validChannel(channel) ? perChannel[static_cast<std::size_t>(channel)] : 0;
            }
            /** Note-ons emitted on a channel so far; a change marks a new note (gate retrigger). */
            std::uint32_t noteOnCount(int channel) const noexcept
            {
                return validChannel(channel) ? onCounts[static_cast<std::size_t>(channel)] : 0u;
            }

            std::size_t pendingCount() const noexcept
            {
                return count;
            }
            std::uint64_t droppedEvents() const noexcept
            {
                return dropped;
            }

          private:
            struct Pending
            {
                double time = 0.0;
                PreparedEvent event;
            };

            static bool validChannel(int channel) noexcept
            {
                return channel >= 0 && channel < kChannels;
            }
            static std::size_t index(int channel, int note) noexcept
            {
                return static_cast<std::size_t>(channel * kNotes + note);
            }
            static bool tracked(const PreparedEvent& e) noexcept
            {
                return validChannel(e.channel) && e.data2 >= 0 && e.data2 < kNotes;
            }

            /** Full queue: keep note-offs by discarding the latest pending note-on. */
            bool makeRoomFor(const PreparedEvent& event) noexcept
            {
                ++dropped;
                if (event.type != kNoteOff)
                    return false;
                for (std::size_t i = count; i > 0; --i) {
                    if (pending[i - 1].event.type == kNoteOn) {
                        for (std::size_t j = i; j < count; ++j)
                            pending[j - 1] = pending[j];
                        --count;
                        return true;
                    }
                }
                return false;
            }

            template <typename Emit>
            void deliver(double time, const PreparedEvent& e, Emit& emit) noexcept
            {
                if (e.type == kNoteOn && tracked(e)) {
                    ++sounding[index(e.channel, e.data2)];
                    ++perChannel[static_cast<std::size_t>(e.channel)];
                    ++onCounts[static_cast<std::size_t>(e.channel)];
                } else if (e.type == kNoteOff && tracked(e)) {
                    auto& n = sounding[index(e.channel, e.data2)];
                    if (n == 0)
                        return; // already released (e.g. by releaseAll)
                    --n;
                    --perChannel[static_cast<std::size_t>(e.channel)];
                }
                emit(time, e);
            }

            std::array<Pending, kCapacity> pending{};
            std::size_t count = 0;
            std::array<std::uint16_t, kChannels * kNotes> sounding{};
            std::array<int, kChannels> perChannel{};
            std::array<std::uint32_t, kChannels> onCounts{};
            std::uint64_t dropped = 0;
        };
    } // namespace bridge
} // namespace worldofcake
