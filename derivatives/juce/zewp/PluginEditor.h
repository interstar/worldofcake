#pragma once

#include "PluginProcessor.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/zewp/ZewpControlMetadataGenerated.h"

#include <juce_gui_extra/juce_gui_extra.h>

class ZewpAudioProcessorEditor final : public juce::AudioProcessorEditor, private juce::Timer
{
  public:
    explicit ZewpAudioProcessorEditor(ZewpAudioProcessor&);
    ~ZewpAudioProcessorEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent&) override;
    void mouseDrag(const juce::MouseEvent&) override;
    void mouseUp(const juce::MouseEvent&) override;

  private:
    void timerCallback() override;
    void sendValue(int controlId, double value);
    void sendPoint(worldofcake::bridge::CommandKind, juce::Point<float> viewPoint);
    worldofcake::jucehost::WocJuceCoordinateMapper panelMapper() const;
    /** A world point (the model's 0..WORLD_WIDTH, 0..WORLD_HEIGHT, y down) in the view. */
    juce::Point<float> toView(double x, double y) const;

    ZewpAudioProcessor& processor;
    // Declared before the widgets so it outlives them.
    worldofcake::jucehost::ChromeLookAndFeel lookAndFeel;
    juce::TooltipWindow tooltips{this};
    worldofcake::bridge::ZewpVisualSnapshot snapshot;
    /** The play area's layout cell, and the world fitted inside it at the model's aspect ratio. */
    juce::Rectangle<float> playCell, world;
    juce::Slider population;
    juce::Slider speed;
    worldofcake::jucehost::IconButton reset{worldofcake::metadata::zewp::kReset};
    worldofcake::jucehost::IconButton pause{worldofcake::metadata::zewp::kPause};
    worldofcake::jucehost::ModelMirror<int> shownPopulation;
    worldofcake::jucehost::ModelMirror<double> shownSpeed;
    worldofcake::jucehost::ModelMirror<bool> shownPaused;
    std::uint64_t displayedGeneration = 0;
    bool dragging = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ZewpAudioProcessorEditor)
};
