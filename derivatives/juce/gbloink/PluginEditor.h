#pragma once

#include "PluginProcessor.h"

#include <juce_gui_extra/juce_gui_extra.h>

class GbloinkAudioProcessorEditor final : public juce::AudioProcessorEditor,
                                          private juce::Timer
{
  public:
    explicit GbloinkAudioProcessorEditor(GbloinkAudioProcessor&);
    ~GbloinkAudioProcessorEditor() override = default;

    void paint(juce::Graphics&) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent&) override;

  private:
    void timerCallback() override;
    void sendValue(int controlId, double value);
    void configureSpeedSlider(juce::Slider&, int index, juce::Colour colour);

    GbloinkAudioProcessor& processor;
    worldofcake::bridge::GbloinkVisualSnapshot snapshot;
    juce::Rectangle<int> playArea;
    std::array<juce::Slider, 3> speedSliders;
    std::array<juce::Label, 3> speedLabels;
    juce::ComboBox scaleSelect;
    juce::ToggleButton edgeNotes{"Wall notes"};
    juce::TextButton reset{"Reset"};
    juce::ToggleButton mute{"Mute output"};
    juce::ToggleButton pause{"Pause movement"};
    juce::Label transportStatus;
    juce::Label diagnosticsLabel;
    std::uint64_t displayedGeneration = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GbloinkAudioProcessorEditor)
};
