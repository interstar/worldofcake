#pragma once
#include "PluginProcessor.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/timeslider/TimeSliderControlMetadataGenerated.h"

#include <array>

#include <juce_gui_extra/juce_gui_extra.h>

class TimeSliderAudioProcessorEditor final : public juce::AudioProcessorEditor, private juce::Timer
{
  public:
    explicit TimeSliderAudioProcessorEditor(TimeSliderAudioProcessor& p);
    ~TimeSliderAudioProcessorEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent&) override;

  private:
    void timerCallback() override;
    void sendValue(int controlId, double value);
    worldofcake::jucehost::WocJuceCoordinateMapper panelMapper() const;

    TimeSliderAudioProcessor& processor;
    // Declared before the widgets so it outlives them.
    worldofcake::jucehost::ChromeLookAndFeel lookAndFeel;
    juce::TooltipWindow tooltips{this};
    worldofcake::bridge::TimeSliderControlSnapshot snap;
    std::array<juce::ComboBox, 4> channelSelects;
    worldofcake::jucehost::IconButton reset{worldofcake::metadata::timeslider::kReset};
    worldofcake::jucehost::IconButton pause{worldofcake::metadata::timeslider::kPause};
    std::array<worldofcake::jucehost::ModelMirror<int>, 4> shownChannels;
    worldofcake::jucehost::ModelMirror<bool> shownPaused;
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TimeSliderAudioProcessorEditor)
};
