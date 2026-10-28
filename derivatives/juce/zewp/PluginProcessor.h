#pragma once

#include "ZewpControlRunner.h"

#include <juce_audio_processors/juce_audio_processors.h>

#include <memory>

/**
    Zewp as a plugin. For now it only runs and shows the world: the model's
    events are discarded by the runner (as in Rack), so it sends no MIDI yet.
*/
class ZewpAudioProcessor final : public juce::AudioProcessor
{
  public:
    ZewpAudioProcessor();
    ~ZewpAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    bool isBusesLayoutSupported(const BusesLayout&) const override { return true; }
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;
    void processBlock(juce::AudioBuffer<double>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }
    const juce::String getName() const override { return JucePlugin_Name; }
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return true; }
    bool isMidiEffect() const override { return true; }
    double getTailLengthSeconds() const override { return 0.0; }
    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; }
    void changeProgramName(int, const juce::String&) override {}
    void getStateInformation(juce::MemoryBlock&) override;
    void setStateInformation(const void*, int) override;

    worldofcake::bridge::ZewpVisualSnapshot visualSnapshot() const;
    bool enqueueGuiCommand(const worldofcake::bridge::ControlCommand&) noexcept;

  private:
    std::unique_ptr<worldofcake::bridge::ZewpControlRunner> runner;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ZewpAudioProcessor)
};
