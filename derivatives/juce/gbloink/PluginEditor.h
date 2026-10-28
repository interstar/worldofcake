#pragma once

#include "PluginProcessor.h"
#include "GbloinkPlayfield.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/gbloink/GbloinkControlMetadataGenerated.h"

#include <array>

#include <juce_gui_extra/juce_gui_extra.h>

class GbloinkAudioProcessorEditor final : public juce::AudioProcessorEditor,
                                          private juce::Timer
{
  public:
    explicit GbloinkAudioProcessorEditor(GbloinkAudioProcessor&);
    ~GbloinkAudioProcessorEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent&) override;

  private:
    void timerCallback() override;
    void sendValue(int controlId, double value);
    worldofcake::jucehost::WocJuceCoordinateMapper panelMapper() const;

    GbloinkAudioProcessor& processor;
    // Declared before the widgets so it outlives them.
    worldofcake::jucehost::ChromeLookAndFeel lookAndFeel;
    juce::TooltipWindow tooltips{this};
    worldofcake::bridge::GbloinkVisualSnapshot snapshot;
    juce::Rectangle<int> playArea;
    GbloinkPlayfield playfield;
    juce::ToggleButton visualEffects;
    std::array<juce::Slider, 3> speedSliders;
    std::array<juce::Slider, 3> velocitySliders;
    juce::Slider noteLength;
    juce::ComboBox scaleSelect;
    worldofcake::jucehost::IconButton reset{worldofcake::metadata::gbloink::kReset};
    worldofcake::jucehost::IconButton pause{worldofcake::metadata::gbloink::kPause};
    worldofcake::jucehost::IconButton mute{worldofcake::metadata::gbloink::kMute};
    worldofcake::jucehost::IconButton edgeNotes{worldofcake::metadata::gbloink::kEdge_notes};
    worldofcake::jucehost::ModelMirror<int> shownScale;
    worldofcake::jucehost::ModelMirror<bool> shownEdgeNotes, shownPaused, shownMuted;
    worldofcake::jucehost::ModelMirror<double> shownNoteLength;
    std::array<worldofcake::jucehost::ModelMirror<double>, 3> shownSpeeds;
    std::array<worldofcake::jucehost::ModelMirror<int>, 3> shownVelocities;
    std::uint64_t displayedGeneration = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GbloinkAudioProcessorEditor)
};
