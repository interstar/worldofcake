#pragma once

#include "worldofcake/generated/gbloink/GbloinkControlIdsGenerated.h"
#include "worldofcake/generated/kdiagram/KDiagramControlIdsGenerated.h"
#include "worldofcake/generated/tileland/TileLandControlIdsGenerated.h"
#include "worldofcake/generated/timeslider/TimeSliderControlIdsGenerated.h"
#include "worldofcake/generated/zewp/ZewpControlIdsGenerated.h"

namespace worldofcake::control
{
    namespace gbloink
    {
        constexpr int kPlayArea = kPlayarea;
        constexpr int kSpeedBase = kRedspeed;
        constexpr int kSpeedCount = 3;
        constexpr int kScaleSelect = kScaleselect;

        constexpr int speedUid(int index)
        {
            return kSpeedBase + index;
        }
    } // namespace gbloink

    namespace zewp
    {
        constexpr int kPlayArea = kPlayarea;
    } // namespace zewp

    namespace kdiagram
    {
        constexpr int kPlayArea = kPlayarea;
        constexpr int kSpeedBase = kRedspeed;
        constexpr int kSpeedCount = 3;
        constexpr int kChannelSlider = kChannel;
        constexpr int kCursorSelect = kSelectcursor;
        constexpr int kScaleSelect = kScaleselect;

        constexpr int speedUid(int index)
        {
            return kSpeedBase + index;
        }
    } // namespace kdiagram

    namespace tileland
    {
        constexpr int kPlayArea = kPlayarea;
        constexpr int kSpeedBase = kRedspeed;
        constexpr int kSpeedCount = 3;

        constexpr int speedUid(int index)
        {
            return kSpeedBase + index;
        }
    } // namespace tileland

    namespace timeslider
    {
        constexpr int kTrackCount = 4;

        constexpr int trackUid(int index)
        {
            return index == 0 ? kCc1track : index == 1 ? kCc2track : index == 2 ? kCc3track : kCc4track;
        }
    } // namespace timeslider
} // namespace worldofcake::control
