#pragma once

#include <algorithm>
#include <cstdint>
#include <WorldOfCakeOutputMapping.h>

namespace worldofcake
{
    namespace rack
    {
        inline int clampMidi7(int value)
        {
            return std::max(0, std::min(127, value));
        }

        inline float midi7ToUnipolar10V(int value)
        {
            return static_cast<float>(worldofcake::output::normalizedToUnipolar10V(
                worldofcake::output::midi7ToNormalized(value)));
        }

        inline float midiNoteToOneVoltPerOctave(int note, int zeroVoltNote = 60)
        {
            return static_cast<float>(worldofcake::output::midiNoteToOneVoltPerOctave(note, zeroVoltNote));
        }

        /**
            Gate for one voice fed by NoteOutputScheduler: high while notes sound,
            and briefly low when a new note starts on an already-high gate so
            downstream envelopes see a fresh rising edge.
        */
        struct RetriggerGate
        {
            static constexpr float kGapSeconds = 0.001f;
            std::uint32_t lastNoteOns = 0;
            float lowRemaining = 0.f;
            bool wasHigh = false;

            bool process(int soundingNotes, std::uint32_t noteOns, float sampleTime)
            {
                if (noteOns != lastNoteOns) {
                    if (wasHigh)
                        lowRemaining = kGapSeconds;
                    lastNoteOns = noteOns;
                }
                bool high = soundingNotes > 0;
                if (lowRemaining > 0.f) {
                    lowRemaining -= sampleTime;
                    high = false;
                }
                wasHigh = high;
                return high;
            }
        };

        inline float gate10V(bool high)
        {
            return static_cast<float>(worldofcake::output::gate10V(high));
        }
    } // namespace rack
} // namespace worldofcake
