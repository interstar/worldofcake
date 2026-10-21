#pragma once
#include "PluginProcessor.h"
class TimeSliderAudioProcessorEditor final:public juce::AudioProcessorEditor,private juce::Timer{public:explicit TimeSliderAudioProcessorEditor(TimeSliderAudioProcessor&p);void paint(juce::Graphics&)override;void mouseDown(const juce::MouseEvent&)override;private:void timerCallback()override;TimeSliderAudioProcessor& processor;worldofcake::bridge::TimeSliderControlSnapshot snap;juce::Point<float> lastClick{-1.0f,-1.0f};JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TimeSliderAudioProcessorEditor)};
