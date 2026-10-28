#pragma once
#include "PluginProcessor.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/timeslider/TimesliderControlMetadataGenerated.h"

#include <array>
#include <string>

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
    /** The JUCE target's lane count (`:model :lanes` in apps/timeslider, via openfl.edn). */
    static constexpr std::size_t kLanes = worldofcake::metadata::timeslider::kLaneCount;

    void timerCallback() override;
    void sendValue(int controlId, double value);
    void sendText(int controlId, const juce::String& text);
    worldofcake::jucehost::WocJuceCoordinateMapper panelMapper() const;

    TimeSliderAudioProcessor& processor;
    // Declared before the widgets so it outlives them.
    worldofcake::jucehost::ChromeLookAndFeel lookAndFeel;
    juce::TooltipWindow tooltips{this};
    worldofcake::bridge::TimeSliderControlSnapshot snap;
    std::array<worldofcake::jucehost::CommitTextEditor, kLanes> labels;
    std::array<juce::ComboBox, kLanes> channelSelects;
    std::array<juce::ComboBox, kLanes> ccSelects;
    worldofcake::jucehost::IconButton reset{worldofcake::metadata::timeslider::kReset};
    worldofcake::jucehost::IconButton pause{worldofcake::metadata::timeslider::kPause};
    std::array<worldofcake::jucehost::ModelMirror<int>, kLanes> shownChannels, shownCcNumbers;
    std::array<worldofcake::jucehost::ModelMirror<std::string>, kLanes> shownLabels;
    worldofcake::jucehost::ModelMirror<bool> shownPaused;
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TimeSliderAudioProcessorEditor)
};
