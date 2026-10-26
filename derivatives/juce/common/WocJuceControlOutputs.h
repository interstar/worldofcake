#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

#include <cmath>
#include <functional>
#include <vector>

namespace worldofcake::jucehost {

/**
    Presents a sequencer's control outputs as host parameters (FL Studio Patcher's
    red wires, DAW automation, etc.). The model decides the values (0..1) in Haxe;
    this only declares one parameter per generated output and pushes the
    published values to the host, on the message thread, when they change.

    Output only for now: a value the host writes is overwritten by the model's
    next change.
*/
class ControlOutputParameters final : private juce::Timer
{
  public:
    /** `outputs` is the generated `kControlOutputs` table; `read(i)` returns output i's published value. */
    template <typename Outputs>
    ControlOutputParameters(juce::AudioProcessor& processor, const Outputs& outputs, std::function<float(int)> read)
        : readValue(std::move(read))
    {
        for (const auto& output : outputs) {
            auto* parameter = new juce::AudioParameterFloat(juce::ParameterID{output.id, 1}, output.label,
                                                            juce::NormalisableRange<float>(0.0f, 1.0f), 0.0f);
            processor.addParameter(parameter);
            parameters.push_back(parameter);
        }
        startTimerHz(kUpdateHz);
    }

    ~ControlOutputParameters() override
    {
        stopTimer();
    }

  private:
    static constexpr int kUpdateHz = 60;
    /** Smaller changes than this are not worth a host notification. */
    static constexpr float kEpsilon = 1.0e-4f;

    void timerCallback() override
    {
        for (std::size_t i = 0; i < parameters.size(); ++i) {
            const float value = readValue(static_cast<int>(i));
            if (std::abs(value - parameters[i]->get()) > kEpsilon)
                parameters[i]->setValueNotifyingHost(value);
        }
    }

    std::function<float(int)> readValue;
    std::vector<juce::AudioParameterFloat*> parameters; // owned by the processor
};

} // namespace worldofcake::jucehost
