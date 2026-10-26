#pragma once
#include "GoldenpondControlRunner.h"
#include "NoteOutputScheduler.h"
#include <juce_audio_processors/juce_audio_processors.h>
#include <memory>
#include <atomic>
class GoldenpondAudioProcessor final : public juce::AudioProcessor {
public:
    GoldenpondAudioProcessor(); ~GoldenpondAudioProcessor() override;
    void prepareToPlay(double, int) override; void releaseResources() override {}
    bool isBusesLayoutSupported(const BusesLayout&) const override { return true; }
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;
    void processBlock(juce::AudioBuffer<double>&, juce::MidiBuffer&) override;
    juce::AudioProcessorEditor* createEditor() override; bool hasEditor() const override { return true; }
    const juce::String getName() const override; bool acceptsMidi() const override { return true; }
    bool producesMidi() const override { return true; } bool isMidiEffect() const override { return true; }
    double getTailLengthSeconds() const override { return 0; } int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; } void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; } void changeProgramName(int, const juce::String&) override {}
    void getStateInformation(juce::MemoryBlock&) override; void setStateInformation(const void*, int) override;
    void sendValue(int, double) noexcept; void sendText(int, const juce::String&) noexcept;
    void enqueueGuiCommand(const worldofcake::bridge::ControlCommand& command) noexcept { if (runner) runner->enqueueGuiCommand(command); }
    worldofcake::bridge::GoldenpondVisualSnapshot visualSnapshot() const { return runner ? runner->latestVisualSnapshot() : worldofcake::bridge::GoldenpondVisualSnapshot{}; }
    void requestVisualSnapshot() noexcept { if (runner) runner->requestVisualSnapshot(); }
private:
    template <class T> void process(juce::AudioBuffer<T>&, juce::MidiBuffer&);
    std::unique_ptr<worldofcake::bridge::GoldenpondControlRunner> runner;
    worldofcake::bridge::NoteOutputScheduler notes;
    double rate = 44100; std::int64_t position = 0;
    std::uint64_t epoch = 1; bool hostPlaying = false; bool hostPositionKnown = false; double lastHostTime = 0.0; std::int64_t hostEpochSample = 0;
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GoldenpondAudioProcessor)
};
