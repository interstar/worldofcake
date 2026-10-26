#pragma once

#include "KDiagramControlRunner.h"
#include "NoteOutputScheduler.h"
#include "WocJuceControlOutputs.h"

#include <juce_audio_processors/juce_audio_processors.h>

#include <memory>

/**
    K-Diagram as a MIDI effect: notes when cursors reach nodes, each cursor's
    X/Y as MIDI CCs, and the same X/Y as host parameters. Runs while the host
    transport plays.
*/
class KDiagramAudioProcessor final : public juce::AudioProcessor
{
  public:
    KDiagramAudioProcessor();
    ~KDiagramAudioProcessor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    bool isBusesLayoutSupported(const BusesLayout&) const override { return true; }
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;
    void processBlock(juce::AudioBuffer<double>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }
    const juce::String getName() const override { return JucePlugin_Name; }
    bool acceptsMidi() const override { return true; }
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

    worldofcake::bridge::KDiagramVisualSnapshot visualSnapshot() const;
    bool enqueueGuiCommand(const worldofcake::bridge::ControlCommand&) noexcept;

  private:
    template <typename FloatType>
    void process(juce::AudioBuffer<FloatType>&, juce::MidiBuffer&);
    static void addMidi(juce::MidiBuffer&, const worldofcake::bridge::PreparedEvent&, int sampleOffset);

    std::unique_ptr<worldofcake::bridge::KDiagramControlRunner> runner;
    /** The cursors' X/Y as host parameters (after `runner`, which it reads). */
    std::unique_ptr<worldofcake::jucehost::ControlOutputParameters> outputParameters;
    worldofcake::bridge::NoteOutputScheduler scheduler;
    bool hostPlaying = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(KDiagramAudioProcessor)
};
