#pragma once

#include <algorithm>
#include <cmath>

namespace worldofcake::output
{
    inline double clamp01(double value) noexcept
    {
        return std::max(0.0, std::min(1.0, value));
    }

    inline int normalizedToMidi7(double normalized) noexcept
    {
        return static_cast<int>(std::lround(clamp01(normalized) * 127.0));
    }

    inline double midi7ToNormalized(int value) noexcept
    {
        return static_cast<double>(std::max(0, std::min(127, value))) / 127.0;
    }

    inline double normalizedToUnipolar10V(double normalized) noexcept
    {
        return clamp01(normalized) * 10.0;
    }

    inline double normalizedToBipolar5V(double normalized) noexcept
    {
        return (clamp01(normalized) * 10.0) - 5.0;
    }

    inline double midiNoteToOneVoltPerOctave(int note, int zeroVoltNote = 60) noexcept
    {
        return (static_cast<double>(note) - static_cast<double>(zeroVoltNote)) / 12.0;
    }

    inline double gate10V(bool high) noexcept
    {
        return high ? 10.0 : 0.0;
    }
}
