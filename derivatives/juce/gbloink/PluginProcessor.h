#pragma once

#include "GbloinkControlRunner.h"
#include "WocMidiScheduler.h"

#include <juce_audio_processors/juce_audio_processors.h>

#include <memory>
#include <cstdint>
#include <atomic>

struct GbloinkPluginDiagnostics
{
    bool hostPlaying = false;
    std::uint64_t haxePrepared = 0;
    std::uint64_t bridgeReceived = 0;
    std::uint64_t triggersQueued = 0;
    std::uint64_t midiMessagesEmitted = 0;
    std::uint64_t staleEvents = 0;
};

class GbloinkAudioProcessor final : public juce::AudioProcessor
{
  public:
    GbloinkAudioProcessor();
    ~GbloinkAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    bool isBusesLayoutSupported(const BusesLayout& layouts) const override;
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;
    void processBlock(juce::AudioBuffer<double>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;
    const juce::String getName() const override;
    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;
    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram(int) override;
    const juce::String getProgramName(int) override;
    void changeProgramName(int, const juce::String&) override;
    void getStateInformation(juce::MemoryBlock&) override;
    void setStateInformation(const void*, int) override;

    worldofcake::bridge::GbloinkVisualSnapshot visualSnapshot() const;
    GbloinkPluginDiagnostics diagnostics() const noexcept;
    bool enqueueGuiCommand(const worldofcake::bridge::ControlCommand&) noexcept;
    void setOutputMuted(bool value) noexcept { outputMuted.store(value, std::memory_order_relaxed); }

  private:
    template <typename FloatType>
    void process(juce::AudioBuffer<FloatType>&, juce::MidiBuffer&);

    std::unique_ptr<worldofcake::bridge::GbloinkControlRunner> runner;
    worldofcake::jucehost::WocMidiScheduler scheduler;
    double currentSampleRate = 44100.0;
    std::int64_t fallbackSamplePosition = 0;
    std::uint64_t transportEpoch = 1;
    bool hostPlaying = false;
    std::atomic<bool> outputMuted{false};
    bool lastOutputMuted = false;
    std::atomic<bool> diagnosticHostPlaying{false};
    std::atomic<std::uint64_t> diagnosticBridgeReceived{0};
    std::atomic<std::uint64_t> diagnosticTriggersQueued{0};
    std::atomic<std::uint64_t> diagnosticMidiMessagesEmitted{0};
    std::atomic<std::uint64_t> diagnosticStaleEvents{0};

    static constexpr double lookAheadSeconds = 0.020;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GbloinkAudioProcessor)
};
