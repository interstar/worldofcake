#pragma once

#include <algorithm>
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

        inline float gate10V(bool high)
        {
            return static_cast<float>(worldofcake::output::gate10V(high));
        }
    } // namespace rack
} // namespace worldofcake
