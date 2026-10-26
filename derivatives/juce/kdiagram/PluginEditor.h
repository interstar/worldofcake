#pragma once

#include "PluginProcessor.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/kdiagram/KdiagramControlMetadataGenerated.h"

#include <array>

#include <juce_gui_extra/juce_gui_extra.h>

class KDiagramAudioProcessorEditor final : public juce::AudioProcessorEditor, private juce::Timer
{
  public:
    explicit KDiagramAudioProcessorEditor(KDiagramAudioProcessor&);
    ~KDiagramAudioProcessorEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent&) override;

  private:
    void timerCallback() override;
    void sendValue(int controlId, double value);
    worldofcake::jucehost::WocJuceCoordinateMapper panelMapper() const;
    /** The network lives in -1..1 on both axes, y up. */
    juce::Point<float> toView(double x, double y) const;
    void paintNetwork(juce::Graphics&);

    KDiagramAudioProcessor& processor;
    // Declared before the widgets so it outlives them.
    worldofcake::jucehost::ChromeLookAndFeel lookAndFeel;
    juce::TooltipWindow tooltips{this};
    worldofcake::bridge::KDiagramVisualSnapshot snapshot;
    juce::Rectangle<float> playArea;
    std::array<juce::Slider, 3> speedKnobs;
    juce::Slider noteLength;
    worldofcake::jucehost::SegmentedChoice cursorSelect{worldofcake::metadata::kdiagram::kSelectcursor};
    juce::ComboBox scaleSelect;
    juce::ComboBox channelSelect;
    worldofcake::jucehost::IconButton reset{worldofcake::metadata::kdiagram::kReset};
    worldofcake::jucehost::IconButton pause{worldofcake::metadata::kdiagram::kPause};
    worldofcake::jucehost::IconButton rotateLeft{worldofcake::metadata::kdiagram::kRotate_left};
    worldofcake::jucehost::IconButton rotateRight{worldofcake::metadata::kdiagram::kRotate_right};
    std::array<worldofcake::jucehost::ModelMirror<double>, 3> shownSpeeds;
    worldofcake::jucehost::ModelMirror<double> shownNoteLength;
    worldofcake::jucehost::ModelMirror<int> shownScale, shownChannel;
    worldofcake::jucehost::ModelMirror<bool> shownPaused;
    std::uint64_t displayedGeneration = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(KDiagramAudioProcessorEditor)
};
