#pragma once

namespace worldofcake
{
    namespace rack
    {
        struct TransportControlIds
        {
            int resetControlId;
            int pauseControlId;
        };

        template <typename SendValue>
        inline void syncPauseLatch(float paramValue, int& lastPause, int controlId, const SendValue& sendValue)
        {
            const int paused = paramValue > 0.5f ? 1 : 0;
            if (paused != lastPause) {
                sendValue(controlId, paused);
                lastPause = paused;
            }
        }

        template <typename SendValue>
        inline void sendButtonRisingEdge(float paramValue, float& lastValue, int controlId, const SendValue& sendValue)
        {
            if (paramValue > 0.5f && lastValue <= 0.5f) {
                sendValue(controlId, 1.0);
            }
            lastValue = paramValue;
        }

        template <typename SendValue>
        inline void syncTransport(float pauseParamValue, int& lastPause, float resetParamValue, float& lastResetValue,
                                  TransportControlIds ids, const SendValue& sendValue)
        {
            syncPauseLatch(pauseParamValue, lastPause, ids.pauseControlId, sendValue);
            sendButtonRisingEdge(resetParamValue, lastResetValue, ids.resetControlId, sendValue);
        }
    } // namespace rack
} // namespace worldofcake
