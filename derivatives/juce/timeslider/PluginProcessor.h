#pragma once
#include "TimeSliderControlRunner.h"
#include "WocJuceControlOutputs.h"
#include <juce_audio_processors/juce_audio_processors.h>
#include <memory>
class TimeSliderAudioProcessor final : public juce::AudioProcessor {
public:
 TimeSliderAudioProcessor(); ~TimeSliderAudioProcessor() override;
 void prepareToPlay(double,int) override; void releaseResources() override;
 bool isBusesLayoutSupported(const BusesLayout&) const override { return true; }
 void processBlock(juce::AudioBuffer<float>&,juce::MidiBuffer&) override;
 void processBlock(juce::AudioBuffer<double>&,juce::MidiBuffer&) override;
 juce::AudioProcessorEditor* createEditor() override; bool hasEditor() const override { return true; }
 const juce::String getName() const override; bool acceptsMidi() const override { return false; }
 bool producesMidi() const override { return true; } bool isMidiEffect() const override { return true; }
 double getTailLengthSeconds() const override { return 0; } int getNumPrograms() override { return 1; }
 int getCurrentProgram() override { return 0; } void setCurrentProgram(int) override {}
 const juce::String getProgramName(int) override { return {}; } void changeProgramName(int,const juce::String&) override {}
 void getStateInformation(juce::MemoryBlock&) override; void setStateInformation(const void*,int) override;
 bool enqueue(const worldofcake::bridge::ControlCommand&) noexcept;
 worldofcake::bridge::TimeSliderControlSnapshot snapshot() const;
private:
 template<class T> void process(juce::AudioBuffer<T>&,juce::MidiBuffer&);
 std::unique_ptr<worldofcake::bridge::TimeSliderControlRunner> runner; double rate=44100; std::int64_t position=0;
 /** The lanes as host parameters (after `runner`, which it reads). */
 std::unique_ptr<worldofcake::jucehost::ControlOutputParameters> outputParameters;
 JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TimeSliderAudioProcessor)
};
