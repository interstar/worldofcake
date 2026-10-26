#pragma once

#include <WorldOfCakeBridgeTypes.h>

namespace worldofcake
{
    namespace rack
    {
        /** True once per press of a momentary Rack button. */
        inline bool risingEdge(float paramValue, float& lastValue)
        {
            const bool rose = paramValue > 0.5f && lastValue <= 0.5f;
            lastValue = paramValue;
            return rose;
        }

        template <typename SendValue>
        inline void sendButtonRisingEdge(float paramValue, float& lastValue, int controlId, const SendValue& sendValue)
        {
            if (risingEdge(paramValue, lastValue))
                sendValue(controlId, 1.0);
        }

        /**
            A latched Rack param presents a model flag (pause, mute). When the user
            flips it, send the lifecycle command; the model owns the flag itself.
        */
        template <typename Enqueue>
        inline void syncLifecycleLatch(float paramValue, int& lastValue, bridge::ControlCommand (*makeCommand)(bool),
                                       const Enqueue& enqueue)
        {
            const int on = paramValue > 0.5f ? 1 : 0;
            if (on != lastValue) {
                enqueue(makeCommand(on != 0));
                lastValue = on;
            }
        }

        /** Pause latch plus reset button, shared by every module. */
        template <typename Enqueue>
        inline void syncTransport(float pauseParamValue, int& lastPause, float resetParamValue, float& lastResetValue,
                                  const Enqueue& enqueue)
        {
            syncLifecycleLatch(pauseParamValue, lastPause, bridge::pauseCommand, enqueue);
            if (risingEdge(resetParamValue, lastResetValue))
                enqueue(bridge::resetCommand());
        }
    } // namespace rack
} // namespace worldofcake
