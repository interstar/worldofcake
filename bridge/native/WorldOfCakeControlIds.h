#pragma once

#include "worldofcake/generated/gbloink/GbloinkControlIdsGenerated.h"
#include "worldofcake/generated/kdiagram/KDiagramControlIdsGenerated.h"
#include "worldofcake/generated/tileland/TileLandControlIdsGenerated.h"
#include "worldofcake/generated/timeslider/TimeSliderControlIdsGenerated.h"
#include "worldofcake/generated/zewp/ZewpControlIdsGenerated.h"
#include "worldofcake/generated/goldenpond/GoldenpondControlIdsGenerated.h"

namespace worldofcake::control
{
    namespace gbloink
    {
        constexpr int kPlayArea = kPlayarea;
        constexpr int kScaleSelect = kScaleselect;

        // Per-ball controls by ball index. Control IDs follow layout order, so they are listed, not computed.
        constexpr int speedUid(int index)
        {
            return index == 0 ? kRedspeed : (index == 1 ? kGreenspeed : kBluespeed);
        }

        constexpr int noteVelocityUid(int index)
        {
            return index == 0 ? kRedvelocity : (index == 1 ? kGreenvelocity : kBluevelocity);
        }
    } // namespace gbloink

    namespace zewp
    {
        constexpr int kPlayArea = kPlayarea;
    } // namespace zewp

    namespace kdiagram
    {
        constexpr int kPlayArea = kPlayarea;
        constexpr int kCursorSelect = kSelectcursor;
        constexpr int kScaleSelect = kScaleselect;

        // Speed controls by cursor. Control IDs follow layout order, so they are listed, not computed.
        constexpr int speedUid(int index)
        {
            return index == 0 ? kRedspeed : (index == 1 ? kGreenspeed : kBluespeed);
        }
    } // namespace kdiagram

    namespace tileland
    {
        constexpr int kPlayArea = kPlayarea;
        constexpr int kSpeedCount = 3;

        // Speed controls by cursor. Control IDs follow each target's order, so they are listed, not computed.
        constexpr int speedUid(int index)
        {
            return index == 0 ? kRedspeed : (index == 1 ? kGreenspeed : kBluespeed);
        }
    } // namespace tileland

} // namespace worldofcake::control
