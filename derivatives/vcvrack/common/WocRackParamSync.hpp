#pragma once

#include <cmath>

namespace worldofcake
{
    namespace rack
    {
        template <typename LastValue, typename SendValue>
        inline void syncControlValue(double value, LastValue& lastValue, double epsilon, int controlId,
                                     const SendValue& sendValue)
        {
            if (std::abs(value - static_cast<double>(lastValue)) > epsilon) {
                sendValue(controlId, value);
                lastValue = static_cast<LastValue>(value);
            }
        }

        template <typename LastValue, typename SendValue>
        inline void syncControlValueExact(int value, LastValue& lastValue, int controlId, const SendValue& sendValue)
        {
            if (value != lastValue) {
                sendValue(controlId, value);
                lastValue = static_cast<LastValue>(value);
            }
        }

        template <typename LastValue, typename SendValue>
        inline void syncBoundedControlValueExact(int value, int minimum, int maximum, LastValue& lastValue,
                                                 int controlId, const SendValue& sendValue)
        {
            if (value != lastValue) {
                if (value >= minimum && value <= maximum) {
                    sendValue(controlId, value);
                }
                lastValue = static_cast<LastValue>(value);
            }
        }

        template <typename ReadValue, typename SendValue>
        inline void syncIndexedControlValues(int count, int firstControlId, float* lastValues, double epsilon,
                                             const ReadValue& readValue, const SendValue& sendValue)
        {
            for (int i = 0; i < count; i++) {
                syncControlValue(readValue(i), lastValues[i], epsilon, firstControlId + i, sendValue);
            }
        }
    } // namespace rack
} // namespace worldofcake
