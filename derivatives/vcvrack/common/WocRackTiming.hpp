#pragma once

namespace worldofcake
{
    namespace rack
    {
        /** Control-thread wake-up cadence. Models are advanced by the real time elapsed
            between wake-ups (see ControlThread), never by a nominal step. */
        constexpr double kControlPeriodSeconds = 1.0 / 60.0;
    } // namespace rack
} // namespace worldofcake
