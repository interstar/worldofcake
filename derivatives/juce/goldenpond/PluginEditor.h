#pragma once
#include "PluginProcessor.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/goldenpond/GoldenpondControlMetadataGenerated.h"
#include <juce_gui_extra/juce_gui_extra.h>
#include <functional>

class GoldenpondAudioProcessorEditor final : public juce::AudioProcessorEditor, private juce::Timer {
public:
    explicit GoldenpondAudioProcessorEditor(GoldenpondAudioProcessor&);
    ~GoldenpondAudioProcessorEditor() override;
    void paint(juce::Graphics&) override;
    void resized() override;

private:
    worldofcake::jucehost::WocJuceCoordinateMapper panelMapper() const;
    void paintScore(juce::Graphics&);

    GoldenpondAudioProcessor& processor;
    // Declared before the widgets so it outlives them.
    worldofcake::jucehost::ChromeLookAndFeel lookAndFeel;
    juce::TooltipWindow tooltips{this};
    juce::Rectangle<int> playArea;
    std::array<juce::Slider, 11> knobs;
    std::array<double, 11> pendingKnobValues{};
    std::array<juce::ComboBox, 3> selects;
    std::array<worldofcake::jucehost::CommitTextEditor, 5> texts;
    worldofcake::jucehost::IconButton reset{worldofcake::metadata::goldenpond::kReset};
    worldofcake::jucehost::IconButton pause{worldofcake::metadata::goldenpond::kPause};
    worldofcake::jucehost::IconButton mute{worldofcake::metadata::goldenpond::kMute};
    worldofcake::jucehost::ModelMirror<double> shownBpm;
    worldofcake::jucehost::ModelMirror<bool> shownPaused, shownMuted;
    worldofcake::bridge::GoldenpondVisualSnapshot snapshot;
    std::uint64_t hydratedStateRevision = 0;
    void timerCallback() override;
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GoldenpondAudioProcessorEditor)
};
